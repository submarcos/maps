#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: 01_download.sh
# Description: Télécharge un extrait OpenStreetMap (PBF) depuis Geofabrik ou URL
# ==============================================================================

AREA="${1:-monaco}"
DATA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../data" && pwd)"
mkdir -p "${DATA_DIR}"

echo -e "\033[1;34m==>\033[0m Téléchargement de l'extrait OSM : \033[1;32m${AREA}\033[0m"

# Si c'est une URL complète
if [[ "${AREA}" =~ ^https?:// ]]; then
    TARGET_FILE="${DATA_DIR}/data.osm.pbf"
    echo "Téléchargement direct depuis l'URL : ${AREA}"
    curl -L --progress-bar "${AREA}" -o "${TARGET_FILE}"
else
    # Mapping des noms courts courants vers les chemins Geofabrik
    declare -A GEOFABRIK_MAP=(
        ["monaco"]="europe/monaco-latest.osm.pbf"
        ["andorra"]="europe/andorra-latest.osm.pbf"
        ["luxembourg"]="europe/luxembourg-latest.osm.pbf"
        ["liechtenstein"]="europe/liechtenstein-latest.osm.pbf"
        ["ile-de-france"]="europe/france/ile-de-france-latest.osm.pbf"
        ["rhone-alpes"]="europe/france/rhone-alpes-latest.osm.pbf"
        ["bretagne"]="europe/france/bretagne-latest.osm.pbf"
        ["alsace"]="europe/france/alsace-latest.osm.pbf"
        ["france"]="europe/france-latest.osm.pbf"
        ["switzerland"]="europe/switzerland-latest.osm.pbf"
        ["belgium"]="europe/belgium-latest.osm.pbf"
    )

    if [[ -n "${GEOFABRIK_MAP[${AREA}]:-}" ]]; then
        GEO_PATH="${GEOFABRIK_MAP[${AREA}]}"
    else
        # Recherche par défaut sous europe/ si non préfixé
        if [[ "${AREA}" != *"/"* ]]; then
            GEO_PATH="europe/${AREA}-latest.osm.pbf"
        else
            GEO_PATH="${AREA}-latest.osm.pbf"
        fi
    fi

    URL="https://download.geofabrik.de/${GEO_PATH}"
    TARGET_FILE="${DATA_DIR}/data.osm.pbf"

    echo "Téléchargement depuis : ${URL}"
    if curl --head --silent --fail "${URL}" > /dev/null; then
        curl -L --progress-bar "${URL}" -o "${TARGET_FILE}"
    else
        echo -e "\033[1;31mErreur :\033[0m Impossible de trouver l'extrait sur ${URL}."
        echo "Exemples valides : monaco, andorra, luxembourg, france, ile-de-france ou une URL directe."
        exit 1
    fi
fi

echo "${AREA}" > "${DATA_DIR}/.area"
SIZE=$(du -h "${TARGET_FILE}" | cut -f1)
echo -e "\033[1;32m✔ Téléchargement terminé avec succès !\033[0m Fichier sauvegardé : ${TARGET_FILE} (${SIZE})"
