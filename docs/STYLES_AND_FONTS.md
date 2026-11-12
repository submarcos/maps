# Guide des Styles, Polices et Sprites

Makina Maps sert nativement les spécifications **Mapbox GL Style / MapLibre GL Style**. Ce document explique comment ajouter des styles, intégrer de nouvelles polices de caractères et personnaliser vos icônes.

---

## 1. Styles Inclus par Défaut

Le projet intègre trois styles prêts à l'emploi dans `styles/` :

1. **OSM Bright** (`styles/osm-bright/`) :
   - Style cartographique complet avec un contraste clair et net.
   - Idéal pour un affichage généraliste (rues, transports, bâtiments, espaces verts, hydrographie).
   - Point d'accès : `http://localhost:8080/styles/bright/style.json`
2. **OSM Liberty** (`styles/osm-liberty/`) :
   - Style moderne et soigné inspiré de la charte Mapbox Streets.
   - Point d'accès : `http://localhost:8080/styles/liberty/style.json`
3. **Minimal Basic** (`styles/basic/`) :
   - Style épuré aux tons neutres, parfait comme fond de plan pour superposer des couches de données métier (GeoJSON, heatmaps, tracés GPS).
   - Point d'accès : `http://localhost:8080/styles/basic/style.json`

---

## 2. Structure d'un Fichier de Style

Dans chaque dossier de style, le fichier `style.json` contient :

```json
{
  "version": 8,
  "name": "Mon Style Personnalisé",
  "sources": {
    "openmaptiles": {
      "type": "vector",
      "url": "mbtiles://{v3}"
    }
  },
  "sprite": "{styleJsonFolder}/sprites/mon-sprite",
  "glyphs": "{fontstack}/{range}.pbf",
  "layers": [ ... ]
}
```

### Variables dynamiques interprétées automatiquement :
- `mbtiles://{v3}` : Remplacé automatiquement par l'URL TileJSON interne du serveur de tuiles vectorielles.
- `{styleJsonFolder}` : Remplacé par l'URL relative menant au dossier du style en cours.
- `{fontstack}/{range}.pbf` : Remplacé par l'URL du service de polices de caractères du serveur.

---

## 3. Ajouter un Nouveau Style

1. Créez un nouveau répertoire dans `styles/` :
   ```bash
   mkdir -p styles/mon-style
   ```
2. Placez-y votre fichier `style.json`.
3. Déclarez le style dans `config/tileserver/config.json` :
   ```json
   "styles": {
     "mon-style": {
       "style": "mon-style/style.json",
       "serve_rendered": true
     }
   }
   ```
4. Redémarrez les services :
   ```bash
   ./makina restart
   ```
Votre style est immédiatement accessible sur `http://localhost:8080/styles/mon-style/style.json` !

---

## 4. Gestion des Polices (Glyphes SDF)

Les cartes vectorielles WebGL utilisent des glyphes au format **Signed Distance Field (SDF)** découpés en plages de 256 caractères (`0-255.pbf`, `256-511.pbf`, etc.).

### Polices déjà fournies :
Le dossier `fonts/` inclut les familles ouvertes les plus courantes :
- `Open Sans` (Regular, Bold, Italic, Semibold)
- `Noto Sans` (Regular, Bold, Italic)
- `Roboto` (Regular, Medium, Condensed Italic)

### Ajouter une nouvelle police TTF/OTF :
Pour convertir une police `.ttf` en glyphes vectoriels `.pbf`, utilisez l'outil open-source [build-glyphs](https://github.com/orangemug/build-glyphs) ou [node-fontnik](https://github.com/mapbox/node-fontnik) :

```bash
npx build-glyphs "MaPolice.ttf" "fonts/Ma Police Regular"
```

---

## 5. Gestion des Sprites (Icônes et Symboles)

Un sprite est composé de 4 fichiers :
- `sprite.png` et `sprite@2x.png` : Les planches d'images regroupant toutes les icônes (POI, transports, numéros de routes).
- `sprite.json` et `sprite@2x.json` : Les dictionnaires de coordonnées associant chaque identifiant d'icône à sa position `(x, y, width, height)`.

Pour générer vos propres sprites à partir d'un ensemble de fichiers SVG :
```bash
npm install -g @mapbox/spritezero-cli
spritezero styles/mon-style/sprite styles/mon-style/svgs/
spritezero --retina styles/mon-style/sprite@2x styles/mon-style/svgs/
```
