# Architecture de Makina Maps (Modernisé)

## 1. Philosophie & Principes Fondamentaux

La plupart des solutions traditionnelles de génération de tuiles vectorielles (comme Mapnik ou les générateurs d'archives MBTiles statiques) imposent de pré-calculer l'intégralité des millions de tuiles jusqu'au zoom 14 avant de pouvoir les servir. Pour un pays comme la France ou un continent, cela demande des dizaines d'heures de calcul et des centaines de gigaoctets de stockage disque.

**Makina Maps repose sur un paradigme différent : le rendu dynamique à la demande (On-Demand Vector Tiles) combiné à un cache HTTP agressif.**

### Avantages majeurs :
1. **Démarrage quasi instantané** : Dès que les données OSM sont importées dans PostGIS, le serveur est opérationnel. Pas besoin d'attendre la génération des tuiles.
2. **Mises à jour OSM en temps réel** : Les flux de modifications OSM (diffs minutely/hourly) sont injectés dans PostGIS via Imposm3 sans verrouillage.
3. **Invalidation chirurgicale du cache** : Seules les tuiles recouvrant les géométries modifiées par le diff sont expirées du cache Nginx.
4. **Hybride Vectoriel / Raster** : Diffusion native de tuiles vectorielles MVT (`.pbf`) pour les applications modernes WebGL (MapLibre), tout en conservant la capacité de servir des tuiles raster (`.png`) rendues à la volée par TileServer-GL pour les anciens clients (Leaflet raster, QGIS, WMS).

---

## 2. Schéma Global des Flux

```text
       +----------------------------------------------------------------+
       |                     CLIENTS CARTOGRAPHIQUES                    |
       |  - Navigateurs Web (MapLibre GL JS, Mapbox GL JS, OpenLayers)   |
       |  - Applications Mobiles (MapLibre Native, SDK iOS/Android)     |
       |  - Logiciels SIG Desktop (QGIS, ArcGIS, Leaflet)               |
       +-------------------------------+--------------------------------+
                                       |
                         Port 8080     | Requêtes HTTP (PBF, PNG, JSON)
                                       v
       +----------------------------------------------------------------+
       |                     NGINX (Reverse Proxy & Cache)              |
       |  - Gestion CORS, compression Gzip, limitation de débit         |
       |  - Cache local sur disque (/cache)                             |
       |  - Routage intelligent des requêtes                           |
       +---------------+--------------------------------+---------------+
                       |                                |
  Tuiles PBF &         |                                | Styles, Polices,
  Métadonnées TileJSON |                                | Sprites & Raster PNG
                       v                                v
       +-------------------------------+  +-------------------------------+
       |          POSTSERVE            |  |         TILESERVER-GL         |
       | (openmaptiles-tools :8090)    |  |  (maptiler/tileserver-gl)     |
       |  - Serveur MVT Python         |  |  - Rendu Mapbox GL natif      |
       |  - Schéma SQL OpenMapTiles    |  |  - Serveur de styles JSON     |
       +---------------+---------------+  |  - Glyphes de polices (.pbf)  |
                       |                  |  - Sprites (icônes)           |
                       | SQL ST_AsMVT     +-------------------------------+
                       v
       +-------------------------------+
       |       POSTGRESQL / POSTGIS    |
       |  - Schéma OpenMapTiles v3     |
       |  - Index spatiaux GiST        |
       |  - JIT désactivé (jit=off)    |
       +---------------+---------------+
                       ^
                       | Import & Mises à jour incrémentales (diffs)
       +---------------+---------------+
       |           IMPOSM 3            |
       |  - Ingestion OpenStreetMap    |
       |  - Détection tuiles expirées  |
       +-------------------------------+
```

---

## 3. Description Détaillée des Composants

### A. NGINX (Couche Frontale & Cache)
- **Rôle** : Point d'entrée unique sur le port `8080`.
- **Mécanisme de Cache** :
  - Clé de cache pour les tuiles vectorielles : `v3/$tile_path` (ex: `v3/14/8166/5900.pbf`).
  - Cache en mémoire vive des clés (`keys_zone=tiles_cache:50m` = ~400 000 entrées).
  - Stockage persistant sur disque jusqu'à 20 Go (`max_size=20g`).
  - En-tête HTTP retourné : `X-Cache-Status` (`HIT`, `MISS`, `EXPIRED`, `STALE`).
  - Protection contre les tempêtes de requêtes : `proxy_cache_lock on` (si 10 clients demandent la même tuile simultanément, une seule requête est transmise au backend Postserve).

### B. Postserve (Générateur MVT Dynamique)
- **Rôle** : Traduit les requêtes de tuiles vectorielles `/tiles/{z}/{x}/{y}.pbf` en requêtes spatiales PostgreSQL.
- **Fonctionnement** :
  - Il utilise la fonction PostGIS native `ST_AsMVT()` et `ST_AsMVTGeom()`.
  - Les requêtes SQL découpent les géométries selon l'emprise géographique de la tuile (Bounding Box calculée à partir de `z, x, y`).
  - Les calques (bâtiments, routes, eau, occupation du sol) sont agrégés dans un seul buffer binaire Protobuf conforme à la spécification **Mapbox Vector Tile (MVT)**.

### C. PostgreSQL 16 + PostGIS 3.4
- **Optimisation Critique `jit = off`** :
  Par défaut dans PostgreSQL 11+, le compilateur Just-In-Time (JIT) s'active sur les requêtes jugées coûteuses. Or, sur les requêtes MVT exécutées en quelques dizaines de millisecondes, la compilation JIT ajoute un surcoût de 50 à 200 ms par tuile. Sa désactivation est essentielle pour obtenir un débit de plusieurs centaines de tuiles/seconde.
- **Indexation Spatiale** : Index GiST sur toutes les tables de géométries (`geometry_3857`).

### D. TileServer-GL
- **Rôle** :
  - Fournit les fichiers de style MapLibre / Mapbox GL (`osm-bright`, `osm-liberty`, `basic`).
  - Sert les glyphes de police vectorielle (`fonts/{fontstack}/{range}.pbf`) indispensables à l'affichage des étiquettes et toponymes.
  - Sert les sprites (feuilles de sprites PNG + index JSON pour les icônes).
  - Rendu Raster à la volée : si un client demande `/styles/bright/{z}/{x}/{y}.png`, TileServer-GL exécute un moteur headless MapLibre C++ pour peindre la tuile vectorielle en image matricielle.

---

## 4. Cycle de Vie d'une Tuile

1. **Le client** demande la tuile : `GET http://localhost:8080/data/v3/14/8166/5900.pbf`
2. **Nginx** vérifie si `v3/14/8166/5900.pbf` est présent dans `/cache`.
   - **Cas HIT** : La tuile est renvoyée immédiatement depuis le disque en < 1 ms avec `X-Cache-Status: HIT`.
   - **Cas MISS** :
     a. Nginx transfère la requête à `postserve:8090/tiles/14/8166/5900.pbf`.
     b. Postserve exécute la fonction SQL `ST_AsMVT` sur PostgreSQL.
     c. PostgreSQL filtre les données dans la bounding box de la tuile (via index GiST) et assemble le binaire MVT.
     d. Postserve renvoie le buffer binaire à Nginx.
     e. Nginx stocke la tuile dans `/cache` et la délivre au client avec `X-Cache-Status: MISS`.
3. **Mise à jour OSM** :
   Lorsqu'un flux de diff OSM modifie une route située dans cette tuile :
   - Imposm applique le patch en base.
   - Les coordonnées `14/8166/5900` sont inscrites dans la liste des tuiles expirées.
   - Nginx purge la clé correspondante du cache.
   - La prochaine requête générera la tuile fraîche à jour.
