#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: 03_update.sh
# Description: Met à jour les données OSM incrémentalement et invalide le cache
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env
fi

echo -e "\033[1;34m====================================================\033[0m"
echo -e "\033[1;34m     Makina Maps - Mise à jour incrémentale (diffs) \033[0m"
echo -e "\033[1;34m====================================================\033[0m"

# 1. Vérification que PostgreSQL est prêt
echo -e "\033[1;34m[*] Vérification de PostgreSQL...\033[0m"
docker compose up -d postgres >/dev/null 2>&1
until docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-openmaptiles}" -d "${POSTGRES_DB:-openmaptiles}" > /dev/null 2>&1; do
    sleep 2
done

mkdir -p data/expire_tiles data/diffs

# 2. Exécution du script de mise à jour différentielle via le conteneur postserve
docker compose run --rm \
    -e AREA="${AREA:-monaco}" \
    -e REPLICATION_URL="${REPLICATION_URL:-}" \
    -e IMPOSM_MAPPING_FILE=/tileset/build/mapping.yaml \
    -e IMPOSM_CONFIG_FILE=/tileset/build/imposm_config.json \
    -e IMPOSM_DIFF_DIR=/import/expire_tiles \
    -e IMPOSM_CACHE_DIR=/cache \
    -e PGHOST=postgres \
    -e PGPORT=5432 \
    -e PGDATABASE="${POSTGRES_DB:-openmaptiles}" \
    -e PGUSER="${POSTGRES_USER:-openmaptiles}" \
    -e PGPASSWORD="${POSTGRES_PASSWORD:-openmaptiles}" \
    postserve python3 /tileset/scripts/update_osm.py "${@}"

# 3. Traitement des tuiles expirées et invalidation du cache Nginx
EXPIRE_FILES=$(find data/expire_tiles -type f \( -name "*.tiles" -o -name "*.tile" \) 2>/dev/null | wc -l)
if [[ "${EXPIRE_FILES}" -gt 0 ]]; then
    echo -e "\033[1;33m[*] Invalidation du cache Nginx pour les tuiles modifiées...\033[0m"
    docker compose exec -T nginx rm -rf /cache/* 2>/dev/null || true
    find data/expire_tiles -type f \( -name "*.tiles" -o -name "*.tile" \) -delete 2>/dev/null || true
    echo -e "\033[1;32m✔ Cache Nginx invalidé avec succès !\033[0m"
fi

echo -e "\033[1;32m====================================================\033[0m"
echo -e "\033[1;32m✔ Processus de mise à jour terminé.                 \033[0m"
echo -e "\033[1;32m====================================================\033[0m"
