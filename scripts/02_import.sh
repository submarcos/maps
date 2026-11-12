#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: 02_import.sh
# Description: Importe les données OSM dans PostGIS avec le schéma OpenMapTiles
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env
fi

POSTGRES_DB="${POSTGRES_DB:-openmaptiles}"
POSTGRES_USER="${POSTGRES_USER:-openmaptiles}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-openmaptiles}"
PBF_FILE="${1:-data/data.osm.pbf}"

echo -e "\033[1;34m====================================================\033[0m"
echo -e "\033[1;34m        Makina Maps - Import des Données OSM        \033[0m"
echo -e "\033[1;34m====================================================\033[0m"

# 1. Vérification du fichier PBF
if [[ ! -f "${PBF_FILE}" ]]; then
    echo -e "\033[1;33m[!] Aucun fichier ${PBF_FILE} trouvé.\033[0m"
    echo -e "Téléchargement automatique de l'extrait par défaut (${AREA:-monaco})..."
    ./scripts/01_download.sh "${AREA:-monaco}"
fi

PBF_NAME=$(basename "${PBF_FILE}")
echo -e "\033[1;32m[*] Fichier PBF sélectionné :\033[0m ${PBF_FILE}"

# 2. Démarrage de PostgreSQL
echo -e "\033[1;34m[*] Démarrage de PostgreSQL / PostGIS...\033[0m"
docker compose up -d postgres

echo -e "\033[1;34m[*] Attente de la disponibilité de la base de données...\033[0m"
until docker compose exec -T postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" > /dev/null 2>&1; do
    sleep 2
done
echo -e "\033[1;32m✔ PostgreSQL est prêt !\033[0m"

# 3. Génération du mapping Imposm3 et du schéma SQL OpenMapTiles
mkdir -p build data/expire_tiles
echo -e "\033[1;34m[*] Compilation du schéma OpenMapTiles...\033[0m"
docker compose run --rm --entrypoint bash postserve -c "\
    generate-sql /tileset/schema/openmaptiles.yaml > /tileset/build/openmaptiles.sql && \
    generate-imposm3 /tileset/schema/openmaptiles.yaml > /tileset/build/mapping.yaml"

# 4. Import des données Natural Earth (lacs, océans, frontières mondiales) si nécessaire
HAS_NATURAL_EARTH=$(docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -tAc "SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'ne_10m_lakes';" 2>/dev/null || true)
if [[ "${HAS_NATURAL_EARTH}" != "1" ]]; then
    echo -e "\033[1;34m[*] Initialisation des tables Natural Earth mondiales...\033[0m"
    docker compose run --rm import-data ./import_data.sh natural-earth
    docker compose run --rm import-data ./import_data.sh lake-centerline
fi

# Création de la table océan si absente
docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "\
    CREATE TABLE IF NOT EXISTS osm_ocean_polygon (id serial primary key, geometry geometry(Polygon, 3857));" >/dev/null 2>&1 || true

# 5. Import des données OSM via Imposm3
echo -e "\033[1;34m[*] Import des données OSM dans PostGIS avec Imposm3...\033[0m"
docker compose run --rm \
    -e PBF_DATA_DIR=/import \
    -e IMPOSM_MAPPING_FILE=/tileset/build/mapping.yaml \
    -e IMPOSM_CONFIG_FILE=/tileset/build/imposm_config.json \
    -e IMPOSM_DIFF_DIR=/import/expire_tiles \
    -e IMPOSM_CACHE_DIR=/cache \
    -e DIFF_MODE=true \
    postserve import-osm "/import/${PBF_NAME}"

# 6. Import des fonctions SQL et vues spatiales (outils OpenMapTiles + schéma compilé)
echo -e "\033[1;34m[*] Création des vues, index spatiaux et fonctions MVT...\033[0m"
docker compose run --rm \
    -e SQL_TOOLS_DIR=/usr/src/app/sql \
    -e SQL_DIR=/tileset/build \
    postserve import-sql

# 7. Optimisation de la base (VACUUM ANALYZE)
echo -e "\033[1;34m[*] Optimisation du planificateur de requêtes (ANALYZE)...\033[0m"
docker compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "ANALYZE;"

# 7. Nettoyage du cache de tuiles
if [[ -f ./scripts/04_purge_cache.sh ]]; then
    ./scripts/04_purge_cache.sh
fi

echo -e "\033[1;32m====================================================\033[0m"
echo -e "\033[1;32m✔ Import terminé avec succès !                      \033[0m"
echo -e "Lancez la stack avec : \033[1;33m./makina start\033[0m"
echo -e "Puis visualisez la carte sur : \033[1;36mhttp://localhost:${PORT:-8080}\033[0m"
echo -e "\033[1;32m====================================================\033[0m"
