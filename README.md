# Makina Maps (Édition Modernisée)

[![OpenStreetMap](https://img.shields.io/badge/Data-OpenStreetMap-7EBC6F?logo=openstreetmap&logoColor=white)](https://www.openstreetmap.org)
[![MapLibre](https://img.shields.io/badge/Vector%20Tiles-MapLibre%20%2F%20MVT-2A52BE)](https://maplibre.org)
[![Docker](https://img.shields.io/badge/Docker-Compose%20v2-2496ED?logo=docker&logoColor=white)](https://docker.com)
[![License](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)

**Makina Maps** est une plateforme complète et moderne pour **construire, servir et mettre à jour vos propres tuiles vectorielles et rasters** à partir des données [OpenStreetMap](https://www.openstreetmap.org).

Inspiré du projet original de [Makina Corpus](https://github.com/makina-maps/makina-maps), cette version a été **intégralement modernisée, simplifiée et unifiée** pour offrir une expérience d'installation en une seule ligne de commande, sans sous-modules Git complexes, avec des composants récents et un visualiseur cartographique interactif prêt à l'emploi.

---

## 🚀 Pourquoi Makina Maps ? (Le Rendu à la Demande)

La plupart des solutions vectorielles exigent de pré-calculer des gigaoctets d'archives statiques (fichiers `.mbtiles`). Makina Maps utilise une approche différente :

* **Rendu à la demande (On-Demand MVT)** : Les tuiles vectorielles sont générées dynamiquement par PostgreSQL/PostGIS lors de la première requête, puis mises en cache agressivement par NGINX.
* **Mise en route immédiate** : Dès la fin de l'import OSM (quelques secondes pour une ville, quelques minutes pour une région), la carte est disponible.
* **Mises à jour OSM incrémentales (diffs)** : Application des flux de modifications OpenStreetMap sans interruption de service et avec invalidation chirurgicale des tuiles modifiées.
* **Hybride Vectoriel & Raster** : Diffusion de tuiles vectorielles MVT (`.pbf`) pour MapLibre/Mapbox GL et de tuiles matricielles (`.png`) rendues à la volée pour les clients classiques (Leaflet, QGIS).

---

## ⚡ Nouveautés par rapport au Makina Maps d'origine

| Fonctionnalité | Makina Maps (Historique) | Makina Maps (Modernisé) |
| :--- | :--- | :--- |
| **Orchestration Docker** | 2 `docker-compose.yml` disjoints reliés par réseau externe manuel | **1 seul `docker-compose.yml` unifié** avec healthchecks |
| **Installation des Styles & Polices** | 4 commandes `git clone -b gh-pages` manuelles sujettes aux 404 | **Styles & Glyphes de polices pré-embarqués** et configurés |
| **Sous-modules Git** | Sous-modules obligatoires (`git clone --recurse-submodules`) | **Dépôt 100% autonome**, zéro sous-module fragile |
| **Outil de Gestion (CLI)** | Scripts épars numérotés (`10-...`, `20-...`) | **CLI unifié puissant `./makina`** avec aide, couleurs et tests |
| **Visualiseur de Carte** | Ancien template Node/Webpack | **Interface interactive moderne MapLibre GL JS** avec inspecteur de tuiles |
| **Moteur Spatial** | Versions PostgreSQL anciennes / JIT problématique | **PostgreSQL 16 + PostGIS 3.4** avec optimisation `jit=off` |
| **Cache & Purge** | Compilation manuelle complexe de Nginx avec module obsolète | **Nginx Alpine optimisé**, streaming rapide et purge simple |

---

## ⏱️ Démarrage Rapide (En 3 minutes)

### 1. Cloner ou naviguer dans le dossier du projet
```bash
cd makina-maps
```

### 2. Initialiser l'environnement
```bash
./makina init
```

### 3. Télécharger et importer un extrait (Exemple : Monaco ou Andorre)
```bash
# Télécharger les données OSM
./makina download monaco

# Importer dans PostGIS et générer les calques OpenMapTiles
./makina import

# Lancer tous les services
./makina start
```

### 4. Visualiser la carte !
Ouvrez votre navigateur sur : **[http://localhost:8080](http://localhost:8080)**

---

## 🧭 Référence des Commandes CLI (`./makina`)

Le script maître `./makina` (ou `make <action>`) centralise toutes les opérations :

| Commande | Description |
| :--- | :--- |
| `./makina init` | Vérifie les prérequis (Docker, cURL) et initialise les dossiers de données. |
| `./makina download [zone]` | Télécharge un extrait Geofabrik (`monaco`, `andorra`, `luxembourg`, `ile-de-france`, `france`...) ou une URL directe. |
| `./makina import [fichier.pbf]` | Compile le schéma OpenMapTiles et injecte les données dans PostGIS. |
| `./makina start` (ou `up`) | Démarre l'ensemble de la pile de conteneurs en arrière-plan. |
| `./makina stop` (ou `down`) | Arrête les conteneurs proprement. |
| `./makina restart` | Redémarre tous les services. |
| `./makina status` (ou `ps`) | Affiche l'état des conteneurs et les ports exposés. |
| `./makina logs [service]` | Affiche les journaux en direct (`postgres`, `postserve`, `tileserver-gl`, `nginx`). |
| `./makina test` | Exécute la suite de tests d'intégration automatisés sur les points d'accès. |
| `./makina update` | Télécharge et applique les diffs OSM récents et purge les tuiles expirées. |
| `./makina purge-cache` | Vide l'intégralité du cache de tuiles de Nginx. |
| `./makina export-mbtiles` | *(Optionnel)* Exporte la base vectorielle en archive autonome `.mbtiles`. |
| `./makina reset` | **Attention :** Réinitialise complètement la base et supprime les volumes. |

---

## 🌐 Points d'Accès et API

Le serveur écoute par défaut sur le port **`8080`** (modifiable dans `.env`) :

| Ressource | URL | Format | Description |
| :--- | :--- | :--- | :--- |
| **Visualiseur Web** | `http://localhost:8080/` | HTML | Interface graphique interactive avec inspecteur de tuiles. |
| **TileJSON** | `http://localhost:8080/data/v3.json` | JSON | Métadonnées de la source vectorielle OpenMapTiles v3. |
| **Tuiles Vectorielles** | `http://localhost:8080/data/v3/{z}/{x}/{y}.pbf` | PBF (MVT) | Tuiles vectorielles brutes servies par Postserve & Nginx. |
| **Style Bright** | `http://localhost:8080/styles/bright/style.json` | JSON | Spécification Mapbox GL pour le style OSM Bright. |
| **Style Liberty** | `http://localhost:8080/styles/liberty/style.json` | JSON | Style moderne inspiré de Mapbox Streets. |
| **Style Basic** | `http://localhost:8080/styles/basic/style.json` | JSON | Style minimal pour superposition de données. |
| **Tuiles Raster** | `http://localhost:8080/styles/bright/{z}/{x}/{y}.png` | PNG | Rendu image matriciel calculé à la volée. |
| **Glyphes Polices** | `http://localhost:8080/fonts/{fontstack}/{range}.pbf` | PBF (SDF) | Polices de caractères vectorielles (Open Sans, Noto, Roboto). |
| **Sprites (Icônes)** | `http://localhost:8080/styles/bright/sprite.png` | PNG / JSON | Planches d'icônes et symboles pour les styles. |
| **Santé / Health** | `http://localhost:8080/health` | JSON | Sonde de disponibilité HTTP (`{"status":"ok"}`). |
| **Statut NGINX** | `http://localhost:8082/nginx_status` | Texte | Métriques de débit et connexions actives Nginx. |

---

## 💻 Intégration dans vos Applications

### 1. MapLibre GL JS (Recommandé)
```html
<div id="map" style="width: 100%; height: 500px;"></div>
<script src="https://unpkg.com/maplibre-gl@3.6.2/dist/maplibre-gl.js"></script>
<link href="https://unpkg.com/maplibre-gl@3.6.2/dist/maplibre-gl.css" rel="stylesheet" />

<script>
  const map = new maplibregl.Map({
    container: 'map',
    style: 'http://localhost:8080/styles/bright/style.json',
    center: [7.42, 43.73], // Longitude, Latitude
    zoom: 13
  });
</script>
```

### 2. Leaflet (Tuiles Raster PNG)
```javascript
const map = L.map('map').setView([43.73, 7.42], 13);

L.tileLayer('http://localhost:8080/styles/bright/{z}/{x}/{y}.png', {
  maxZoom: 19,
  attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
}).addTo(map);
```

### 3. OpenLayers (Tuiles Vectorielles MVT)
```javascript
import VectorTileLayer from 'ol/layer/VectorTile';
import VectorTileSource from 'ol/source/VectorTile';
import MVT from 'ol/format/MVT';

const layer = new VectorTileLayer({
  source: new VectorTileSource({
    format: new MVT(),
    url: 'http://localhost:8080/data/v3/{z}/{x}/{y}.pbf'
  })
});
```

### 4. QGIS Desktop
1. Dans le panneau de navigation, faites un clic droit sur **Vector Tiles** > **Nouvelle connexion générique**.
2. Nommez la connexion (ex: `Makina Maps Local`).
3. Renseignez l'URL : `http://localhost:8080/data/v3/{z}/{x}/{y}.pbf` avec zoom min `0` et max `14`.
4. Glissez-déposez la couche dans votre projet !

---

## 🏗️ Architecture Technique

```ascii-art
                      [ Client Web / SIG / Mobile ]
                                    │
                                    │ HTTP :8080
                                    ▼
       ┌────────────────────────────────────────────────────────┐
       │             NGINX (Reverse Proxy & Cache)              │
       │    - Cache disque 20 Go (/cache) avec rate-limiting    │
       │    - En-tête X-Cache-Status (HIT / MISS)               │
       └──────────────┬──────────────────────────┬──────────────┘
                      │                          │
        /data/v3/*.pbf│            /styles/*,    │
        /data/v3.json │            /fonts/*,     │
                      ▼            /sprites/*    ▼
       ┌────────────────────────┐  ┌────────────────────────────┐
       │        POSTSERVE       │  │       TILESERVER-GL        │
       │  (openmaptiles-tools)  │  │  (maptiler/tileserver-gl)  │
       │  - Rendu MVT dynamique │  │  - Rendu Raster PNG        │
       │  - Schéma v3 PostGIS   │  │  - Serveur de styles JSON  │
       └──────────────┬─────────┘  └────────────────────────────┘
                      │
                      │ SQL ST_AsMVT() (jit = off)
                      ▼
       ┌────────────────────────────────────────────────────────┐
       │                 POSTGRESQL 16 / POSTGIS                │
       │          - Données OSM importées par Imposm3           │
       │          - Index spatiaux GiST sur géométries          │
       └────────────────────────────────────────────────────────┘
```

Pour les détails d'implémentation, consultez **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

---

## 📚 Documentation Complète

* **[Architecture Détaillée](docs/ARCHITECTURE.md)** : Flux de requêtes, stratégie de cache Nginx et fonctionnement MVT.
* **[Guide de Démarrage (Quickstart)](docs/QUICKSTART.md)** : Tutoriel pas-à-pas pour démarrer en quelques minutes.
* **[Guide d'Import & Dimensionnement](docs/IMPORT_GUIDE.md)** : Liste des extraits, estimations mémoire/RAM et personnalisation du schéma.
* **[Styles, Polices & Sprites](docs/STYLES_AND_FONTS.md)** : Personnaliser l'apparence de la carte, ajouter des polices TTF et des icônes SVG.
* **[Mises à Jour OSM & Réplication](docs/UPDATES_AND_REPLICATION.md)** : Synchronisation en direct avec les diffs OpenStreetMap.
* **[Déploiement en Production](docs/PRODUCTION.md)** : Recommandations HTTPS, systemd, reverse proxy et supervision.

---

## 📄 Licence

Ce projet est distribué sous licence open-source **BSD 3-Clause**.
Les données cartographiques sont issues d'**[OpenStreetMap](https://www.openstreetmap.org/copyright)** (ODbL).
