# Guide d'Import et Dimensionnement OpenStreetMap

Ce document détaille comment sélectionner, télécharger et importer des données OpenStreetMap de toute taille, de la ville au continent, avec les bonnes pratiques d'allocation mémoire et de performance.

---

## 1. Origine des Données (Extraits Geofabrik)

Le service [Geofabrik Downloads](https://download.geofabrik.de/) fournit des extraits quotidiens d'OpenStreetMap découpés par continents, pays et régions.

### Alias supportés nativement par `./makina download <zone>` :

| Nom court | Région correspondante | Taille PBF approximative |
| :--- | :--- | :--- |
| `monaco` | Principauté de Monaco | ~1.5 Mo |
| `andorra` | Andorre (Pyrénées) | ~2.5 Mo |
| `liechtenstein` | Liechtenstein | ~4 Mo |
| `luxembourg` | Grand-Duché de Luxembourg | ~35 Mo |
| `alsace` | Alsace (France) | ~110 Mo |
| `ile-de-france` | Paris & Île-de-France | ~180 Mo |
| `bretagne` | Bretagne | ~190 Mo |
| `rhone-alpes` | Rhône-Alpes | ~250 Mo |
| `france` | France Métropolitaine | ~4.2 Go |
| `switzerland` | Suisse | ~450 Mo |
| `belgium` | Belgique | ~380 Mo |

### Téléchargement via URL personnalisée :
Vous pouvez fournir n'importe quelle URL d'extrait OSM :
```bash
./makina download https://download.geofabrik.de/europe/germany/berlin-latest.osm.pbf
```

---

## 2. Tableau de Dimensionnement et Ressources

L'import d'OpenStreetMap fait intervenir **Imposm3** (qui parse le PBF et indexe les relations/nœuds dans un cache local) et **PostgreSQL** (qui crée les géométries spatiales et les index GiST).

| Zone | Taille PBF | Cache Imposm | Taille Base PostGIS | RAM Conseillée | Temps Import (SSD moderne) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Monaco** | 1.5 Mo | ~4 Mo | ~12 Mo | 2 Go | ~10 secondes |
| **Andorre** | 2.5 Mo | ~6 Mo | ~25 Mo | 2 Go | ~25 secondes |
| **Île-de-France** | 180 Mo | ~450 Mo | ~2.2 Go | 4 Go | ~3 à 5 minutes |
| **Rhône-Alpes** | 250 Mo | ~600 Mo | ~3.1 Go | 4 Go | ~5 à 7 minutes |
| **France** | 4.2 Go | ~9 Go | ~45 Go | 16 Go | ~45 à 90 minutes |
| **Europe** | ~28 Go | ~55 Go | ~280 Go | 32 à 64 Go | ~10 à 18 heures |
| **Planet (Monde)** | ~75 Go | ~160 Go | ~900 Go | 64 à 128 Go | ~30 à 48 heures |

> [!IMPORTANT]
> L'utilisation d'un stockage **NVMe / SSD** est primordiale. Sur disque rotatif (HDD), les temps d'importation sont multipliés par 5 à 10 en raison des écritures aléatoires sur les index GiST.

---

## 3. Optimisation Mémoire dans `.env`

Pour les imports régionaux ou nationaux importants, éditez `.env` pour allouer plus de ressources à PostgreSQL :

```ini
# Pour une machine avec 16 Go de RAM
POSTGRES_DB=openmaptiles
POSTGRES_USER=openmaptiles
POSTGRES_PASSWORD=openmaptiles

# Parallélisme pour l'import SQL
MAX_PARALLEL_PSQL=8
COPY_CONCURRENCY=8
```

Et ajustez `config/postgres/postgresql.conf` :
```ini
shared_buffers = 4GB          # 25% de la RAM totale
work_mem = 128MB
maintenance_work_mem = 2GB    # Accélère la création des index spatiaux
max_wal_size = 15GB
checkpoint_completion_target = 0.9
```

---

## 4. Personnalisation des Calques (Schema)

Le schéma OpenMapTiles se trouve dans le dossier `schema/` de votre projet :
- `schema/openmaptiles.yaml` : Déclaration générale des calques et niveaux de zoom.
- `schema/layers/` : Définition calque par calque (ex: `building`, `water`, `transportation`, `poi`).

Pour ajouter ou supprimer des balises OSM ou filtrer des données :
1. Modifiez les fichiers YAML du calque concerné dans `schema/layers/<nom>/`.
2. Relancez l'importation :
   ```bash
   ./makina import
   ```
Le script régénérera automatiquement les fichiers `build/mapping.yaml` et `build/openmaptiles.sql`.
