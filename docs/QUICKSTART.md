# Guide de Démarrage Rapide (Quickstart)

Ce tutoriel vous guide pour déployer votre propre serveur de tuiles vectorielles en moins de 3 minutes sur un extrait géographique (par exemple la principauté de Monaco ou Andorre).

---

## 1. Prérequis Système

- **Système d'exploitation** : Linux, macOS ou Windows avec WSL2
- **Logiciels requis** :
  - [Docker](https://docs.docker.com/get-docker/) (version 20.10 ou supérieure)
  - [Docker Compose](https://docs.docker.com/compose/) (v2 ou plugin Docker Compose v5+)
  - `curl`

---

## 2. Déploiement en 3 Commandes

Ouvrez un terminal dans le répertoire du projet :

```bash
cd /home/jec/.gemini/antigravity/scratch/makina-maps
```

### Étape 1 : Initialisation de l'environnement
```bash
./makina init
```
*Cette commande vérifie les dépendances, crée les dossiers nécessaires et configure le fichier `.env`.*

### Étape 2 : Téléchargement d'un extrait OpenStreetMap
Pour commencer rapidement, téléchargez un petit territoire comme Monaco (quelques mégaoctets) :
```bash
./makina download monaco
```
*(Vous pouvez aussi télécharger `andorra`, `luxembourg`, `ile-de-france`, ou toute URL directe `http://...osm.pbf`)*.

### Étape 3 : Import dans la base PostGIS
```bash
./makina import
```
*Le script démarre PostgreSQL, compile le schéma OpenMapTiles, injecte les routes, bâtiments, cours d'eau et toponymes, puis crée les index spatiaux.*

### Étape 4 : Lancement du serveur
```bash
./makina start
```

---

## 3. Accéder à la Carte

Ouvrez votre navigateur web sur :
👉 **[http://localhost:8080](http://localhost:8080)**

Vous arrivez sur le **Visualiseur Cartographique Intégré** :
- Naviguez sur la carte avec la souris ou le pavé tactile.
- Changez de style en un clic (**OSM Bright**, **OSM Liberty**, **Minimal Basic**).
- Observez les coordonnées de la tuile sous votre curseur (`z/x/y`).
- Inspectez les URL exactes des tuiles vectorielles PBF.

---

## 4. Vérification et Tests Automatisés

Pour vérifier que tous les services et points d'accès fonctionnent correctement :

```bash
./makina test
```

Exemple de sortie attendue :
```text
[*] Exécution des tests d'intégration Makina Maps...
  - Test endpoint santé (http://localhost:8080/health) : OK
  - Test visualiseur Web (http://localhost:8080/) : OK
  - Test métadonnées TileJSON (http://localhost:8080/data/v3.json) : OK
  - Test Style Bright (http://localhost:8080/styles/bright/style.json) : OK

✔ Tous les services répondent parfaitement !
```

---

## 5. Tester avec d'autres Territoires

Pour importer une autre zone géographique :
```bash
# 1. Télécharger la nouvelle zone (ex: Andorre ou Île-de-France)
./makina download andorra

# 2. Importer les nouvelles données
./makina import

# 3. Le serveur sert automatiquement les nouvelles tuiles !
```

---

## 6. Arrêt et Gestion

- Pour arrêter les conteneurs :
  ```bash
  ./makina stop
  ```
- Pour redémarrer :
  ```bash
  ./makina start
  ```
- Pour inspecter les logs :
  ```bash
  ./makina logs postserve
  ./makina logs nginx
  ```
