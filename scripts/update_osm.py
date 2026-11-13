#!/usr/bin/env python3
"""
Makina Maps - OSM Differential Updater
Télécharge et applique les diffs incrémentaux OpenStreetMap (Geofabrik) avec Imposm3.
"""

import os
import sys
import glob
import json
import shutil
import urllib.request
import urllib.error
import subprocess
from datetime import datetime
from pathlib import Path

# Mapping des zones usuelles vers les chemins Geofabrik
GEOFABRIK_MAP = {
    "monaco": "europe/monaco-latest.osm.pbf",
    "andorra": "europe/andorra-latest.osm.pbf",
    "luxembourg": "europe/luxembourg-latest.osm.pbf",
    "liechtenstein": "europe/liechtenstein-latest.osm.pbf",
    "ile-de-france": "europe/france/ile-de-france-latest.osm.pbf",
    "rhone-alpes": "europe/france/rhone-alpes-latest.osm.pbf",
    "bretagne": "europe/france/bretagne-latest.osm.pbf",
    "alsace": "europe/france/alsace-latest.osm.pbf",
    "france": "europe/france-latest.osm.pbf",
    "switzerland": "europe/switzerland-latest.osm.pbf",
    "belgium": "europe/belgium-latest.osm.pbf",
}


def log(msg, color="34"):
    print(f"\033[1;{color}m[*]\033[0m {msg}", flush=True)


def log_success(msg):
    print(f"\033[1;32m✔\033[0m {msg}", flush=True)


def log_warn(msg):
    print(f"\033[1;33m[!]\033[0m {msg}", flush=True)


def log_error(msg):
    print(f"\033[1;31m[✘]\033[0m {msg}", file=sys.stderr, flush=True)


def get_replication_url(area, custom_url=None):
    if custom_url:
        url = custom_url.rstrip("/") + "/"
        return url

    if area.startswith("http://") or area.startswith("https://"):
        if "download.geofabrik.de" in area and "-latest.osm.pbf" in area:
            return area.replace("-latest.osm.pbf", "-updates") + "/"
        raise ValueError(
            f"URL personnalisée non reconnue pour les diffs automatiques: {area}. "
            "Définissez REPLICATION_URL dans .env pour spécifier la source des diffs."
        )

    geo_path = GEOFABRIK_MAP.get(area)
    if not geo_path:
        if "/" in area:
            geo_path = f"{area}-latest.osm.pbf"
        else:
            geo_path = f"europe/{area}-latest.osm.pbf"

    updates_path = geo_path.replace("-latest.osm.pbf", "-updates")
    return f"https://download.geofabrik.de/{updates_path}/"


def seq_to_path(seq: int) -> str:
    s = f"{seq:09d}"
    return f"{s[0:3]}/{s[3:6]}/{s[6:9]}"


def fetch_url(url: str, timeout: int = 15) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": "Makina-Maps-Updater/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read().decode("utf-8")


def download_file(url: str, dest_path: Path, timeout: int = 60):
    req = urllib.request.Request(url, headers={"User-Agent": "Makina-Maps-Updater/1.0"})
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(req, timeout=timeout) as resp, open(dest_path, "wb") as out_file:
        shutil.copyfileobj(resp, out_file)


def parse_state(text: str):
    res = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, v = line.split("=", 1)
            v = v.replace("\\", "").strip()
            res[k.strip()] = v
    seq = res.get("sequenceNumber")
    return {
        "sequence": int(seq) if seq and seq.isdigit() else None,
        "timestamp": res.get("timestamp"),
        "replication_url": res.get("replicationUrl"),
    }


def write_state(file_path: Path, seq: int, timestamp: str, repl_url: str):
    file_path.parent.mkdir(parents=True, exist_ok=True)
    # Imposm expects colons in ISO timestamp to be escaped with \:
    escaped_ts = timestamp.replace(":", "\\:") if "\\:" not in timestamp else timestamp
    content = (
        f"timestamp={escaped_ts}\n"
        f"sequenceNumber={seq}\n"
        f"replicationUrl={repl_url}\n"
    )
    file_path.write_text(content, encoding="utf-8")


def clean_leveldb_locks(cache_dir: Path):
    if cache_dir.exists():
        for lock_file in cache_dir.glob("**/LOCK"):
            try:
                lock_file.unlink()
            except Exception:
                pass


def main():
    area = os.environ.get("AREA", "monaco").strip()
    custom_repl_url = os.environ.get("REPLICATION_URL", "").strip() or None
    diff_dir = Path(os.environ.get("IMPOSM_DIFF_DIR", "/import/expire_tiles"))
    cache_dir = Path(os.environ.get("IMPOSM_CACHE_DIR", "/cache"))
    mapping_file = os.environ.get("IMPOSM_MAPPING_FILE", "/tileset/build/mapping.yaml")
    config_file = os.environ.get("IMPOSM_CONFIG_FILE", "/tileset/build/imposm_config.json")
    
    pg_host = os.environ.get("PGHOST", os.environ.get("POSTGRES_HOST", "postgres"))
    pg_port = os.environ.get("PGPORT", os.environ.get("POSTGRES_PORT", "5432"))
    pg_db = os.environ.get("PGDATABASE", os.environ.get("POSTGRES_DB", "openmaptiles"))
    pg_user = os.environ.get("PGUSER", os.environ.get("POSTGRES_USER", "openmaptiles"))
    pg_password = os.environ.get("PGPASSWORD", os.environ.get("POSTGRES_PASSWORD", "openmaptiles"))

    last_state_file = diff_dir / "last.state.txt"
    staging_diffs_dir = Path("/import/diffs")

    try:
        repl_url = get_replication_url(area, custom_repl_url)
    except ValueError as e:
        log_error(str(e))
        sys.exit(1)

    log(f"Zone configurée : \033[1;32m{area}\033[0m")
    log(f"Serveur de replication : \033[1;36m{repl_url}\033[0m")

    # 1. Vérification de l'état local
    local_seq = None
    local_ts = None
    if last_state_file.exists():
        local_state = parse_state(last_state_file.read_text(encoding="utf-8"))
        local_seq = local_state["sequence"]
        local_ts = local_state["timestamp"]
        log(f"État local : séquence={local_seq}, timestamp={local_ts}")
    else:
        log_warn("Aucun fichier last.state.txt trouvé dans data/expire_tiles/")

    # 2. Récupération du state.txt distant
    try:
        remote_state_text = fetch_url(f"{repl_url}state.txt")
        remote_state = parse_state(remote_state_text)
    except Exception as e:
        log_error(f"Impossible de joindre le serveur de mise à jour ({repl_url}state.txt) : {e}")
        sys.exit(1)

    remote_seq = remote_state["sequence"]
    remote_ts = remote_state["timestamp"]
    if not remote_seq:
        log_error("Réponse du serveur de mise à jour invalide (aucun sequenceNumber).")
        sys.exit(1)

    log(f"Dernier diff disponible sur le serveur : séquence=\033[1;32m{remote_seq}\033[0m ({remote_ts})")

    # 3. Détermination de la plage de diffs à appliquer
    start_seq = None

    # Si local_seq est déjà dans l'ordre de grandeur du serveur de diffs (ex: Geofabrik daily ~ 4000-6000)
    # et n'est pas un numéro minutely de la planète (> 1 000 000)
    if local_seq and (remote_seq - 1000) <= local_seq <= remote_seq:
        start_seq = local_seq + 1
    elif local_ts:
        # Trouver la séquence correspondant au timestamp du PBF initial
        log("Recherche de la séquence correspondant au timestamp initial...")
        curr = remote_seq
        while curr >= max(1, remote_seq - 30):
            p = seq_to_path(curr)
            state_url = f"{repl_url}{p}.state.txt"
            try:
                txt = fetch_url(state_url, timeout=10)
                st = parse_state(txt)
                if st["timestamp"] and st["timestamp"] <= local_ts:
                    start_seq = curr + 1
                    log(f"Séquence de départ trouvée : {start_seq} (base={curr} du {st['timestamp']})")
                    break
            except Exception:
                pass
            curr -= 1

    if start_seq is None:
        if local_seq and local_seq > remote_seq:
            # Numéro planète ou timestamp introuvable
            log_warn(f"Impossible de corréler la séquence locale ({local_seq}) avec les diffs Geofabrik ({remote_seq}).")
            log_warn("Téléchargement du dernier diff en date pour resynchroniser.")
            start_seq = remote_seq
        else:
            log_error(
                "Impossible de déterminer la séquence de départ. Votre base de données est peut-être "
                "trop ancienne (> 30 jours sans diff). Réimportez avec: ./makina import"
            )
            sys.exit(1)

    # 4. Vérification si déjà à jour
    if start_seq > remote_seq:
        log_success(f"Données déjà à jour (séquence {remote_seq} du {remote_ts}). Aucun diff en attente.")
        sys.exit(0)

    diff_count = remote_seq - start_seq + 1
    log(f"\033[1;33m{diff_count}\033[0m diff(s) à appliquer (séquences {start_seq} à {remote_seq})...")

    # 5. Téléchargement des diffs
    staging_diffs_dir.mkdir(parents=True, exist_ok=True)
    # Nettoyage préalable
    for f in staging_diffs_dir.glob("*"):
        try:
            f.unlink()
        except Exception:
            pass

    downloaded_diffs = []
    for seq in range(start_seq, remote_seq + 1):
        p = seq_to_path(seq)
        osc_url = f"{repl_url}{p}.osc.gz"
        state_url = f"{repl_url}{p}.state.txt"
        
        dest_osc = staging_diffs_dir / f"{seq}.osc.gz"
        dest_state = staging_diffs_dir / f"{seq}.state.txt"

        log(f"[{len(downloaded_diffs) + 1}/{diff_count}] Téléchargement : {seq}.osc.gz...")
        try:
            download_file(osc_url, dest_osc)
            download_file(state_url, dest_state)
            downloaded_diffs.append(dest_osc)
        except Exception as e:
            log_error(f"Échec du téléchargement du diff {seq} ({osc_url}) : {e}")
            sys.exit(1)

    # 6. Application des diffs avec Imposm
    log("Application des diffs dans PostgreSQL avec Imposm3...")
    clean_leveldb_locks(cache_dir)

    diff_args = [
        "imposm", "diff",
        "-connection", f"postgis://{pg_user}:{pg_password}@{pg_host}:{pg_port}/{pg_db}",
        "-mapping", mapping_file,
        "-cachedir", str(cache_dir),
        "-diffdir", str(diff_dir),
        "-expiretiles-dir", str(diff_dir),
        "-config", config_file,
    ]
    diff_args.extend([str(p) for p in downloaded_diffs])

    try:
        proc = subprocess.run(diff_args, check=True)
    except subprocess.CalledProcessError as e:
        log_error(f"Erreur lors de l'application des diffs Imposm : code sortie {e.returncode}")
        sys.exit(e.returncode)

    # 7. Mise à jour finale de last.state.txt
    write_state(last_state_file, remote_seq, remote_ts, repl_url)
    log_success(f"last.state.txt mis à jour : séquence {remote_seq} ({remote_ts})")

    # 8. Nettoyage du dossier temporaire de diffs
    shutil.rmtree(staging_diffs_dir, ignore_errors=True)

    log_success(f"Toutes les mises à jour ({diff_count} diffs) ont été appliquées avec succès !")


if __name__ == "__main__":
    main()
