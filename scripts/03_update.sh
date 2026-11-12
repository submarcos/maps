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

echo -e "\033[1;34m[*] Recherche et application des mises à jour OpenStreetMap (diffs)...\033[0m"

mkdir -p data/expire_tiles

# Exécution de import-diff dans le conteneur postserve
docker compose run --rm \
    -e IMPOSM_MAPPING_FILE=/tileset/build/mapping.yaml \
    -e IMPOSM_CONFIG_FILE=/tileset/build/imposm_config.json \
    -e IMPOSM_DIFF_DIR=/import/expire_tiles \
    -e IMPOSM_CACHE_DIR=/cache \
    postserve bash -c "
        if which import-diff >/dev/null 2>&1; then
            import-diff || echo 'Aucun diff en attente.'
        fi
    "

# Traitement des tuiles expirées si générées
EXPIRE_COUNT=$(find data/expire_tiles -name "*.tiles" 2>/dev/null | wc -l)
if [[ "${EXPIRE_COUNT}" -gt 0 ]]; then
    echo -e "\033[1;33m[*] Invalidation du cache Nginx pour les tuiles modifiées...\033[0m"
    docker compose exec -T nginx rm -rf /cache/*
    rm -rf data/expire_tiles/*.tiles
    echo -e "\033[1;32m✔ Cache invalidé avec succès !\033[0m"
else
    echo -e "\033[1;32m✔ Données à jour, aucune tuile à expirer.\033[0m"
fi
