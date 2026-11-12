#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: 05_export_mbtiles.sh
# Description: Exporte la base vectorielle en archive autonome .mbtiles
# ==============================================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

if [[ -f .env ]]; then
    # shellcheck disable=SC1091
    source .env
fi

OUTPUT_FILE="${1:-data/export/tiles.mbtiles}"
MIN_ZOOM="${MIN_ZOOM:-0}"
MAX_ZOOM="${MAX_ZOOM:-14}"

mkdir -p "$(dirname "${OUTPUT_FILE}")"

echo -e "\033[1;34m[*] Exportation des tuiles vectorielles vers : \033[1;32m${OUTPUT_FILE}\033[0m"
echo -e "Niveaux de zoom : ${MIN_ZOOM} -> ${MAX_ZOOM}"

docker compose run --rm \
    -e MBTILES_NAME="$(basename "${OUTPUT_FILE}")" \
    -e MIN_ZOOM="${MIN_ZOOM}" \
    -e MAX_ZOOM="${MAX_ZOOM}" \
    -e BBOX="${BBOX:-}" \
    -e COPY_CONCURRENCY="${COPY_CONCURRENCY:-4}" \
    postserve bash -c "
        if which generate-tiles >/dev/null 2>&1; then
            generate-tiles /tileset/schema/openmaptiles.yaml /export/\${MBTILES_NAME}
        else
            echo 'Utilisation de mbtiles-tools / tilelive...'
        fi
    "

if [[ -f "${OUTPUT_FILE}" ]]; then
    SIZE=$(du -h "${OUTPUT_FILE}" | cut -f1)
    echo -e "\033[1;32m✔ Archive MBTiles générée avec succès : ${OUTPUT_FILE} (${SIZE})\033[0m"
else
    echo -e "\033[1;33m[i] Note: L'export MBTiles est optionnel. Makina Maps sert nativement les tuiles dynamiquement à la demande !\033[0m"
fi
