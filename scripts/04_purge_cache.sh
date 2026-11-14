#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: 04_purge_cache.sh
# Description: Purge complète ou sélective du cache de tuiles Nginx
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

PATTERN="${1:-all}"

echo -e "\033[1;34m[*] Purge du cache Nginx (mode: ${PATTERN})...\033[0m"

if docker compose ps -q nginx >/dev/null 2>&1 && [ -n "$(docker compose ps -q nginx)" ]; then
    if [[ "${PATTERN}" == "all" ]]; then
        docker compose exec -T nginx find /cache -mindepth 1 -delete || true
    else
        docker compose exec -T nginx find /cache -type f -name "*${PATTERN}*" -delete || true
    fi
    echo -e "\033[1;32m✔ Cache purgé dans le conteneur Nginx !\033[0m"
else
    # Nettoyage direct du volume Docker si Nginx n'est pas démarré
    docker volume rm -f makina-maps_nginx_cache 2>/dev/null || true
    docker volume create makina-maps_nginx_cache >/dev/null 2>&1 || true
    echo -e "\033[1;32m✔ Volume de cache réinitialisé !\033[0m"
fi
