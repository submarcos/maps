# Guide des Mises à Jour et Réplication OSM en Temps Réel

L'un des grands atouts hérités de l'esprit Makina Maps est la capacité de garder votre serveur de tuiles **synchronisé avec les modifications quotidiennes ou à la minute d'OpenStreetMap**, sans jamais interrompre le service ni verrouiller les tables de la base de données.

---

## 1. Comment Fonctionne la Réplication

```text
[Serveurs OSM / Geofabrik]
           │
           │ Fichiers de Diff (.osc.gz / minutely, hourly, daily)
           ▼
     [imposm run]  ─── Met à jour ───▶ [PostgreSQL / PostGIS] (sans coupure)
           │
           │ Génère la liste des tuiles impactées
           ▼
  [data/expire_tiles] (ex: 14/8166/5900)
           │
           │ Multiplication des zooms (z10 -> z14)
           ▼
    [Purge Nginx]    ─── Supprime ────▶ [Fichiers dans /cache]
```

1. **Téléchargement du flux de modifications** :
   Les diffs (`.osc.gz`) contiennent uniquement les nœuds, chemins et relations créés, modifiés ou supprimés dans OSM depuis le dernier import.
2. **Application transactionnelle avec Imposm** :
   Imposm applique les modifications dans PostGIS dans une transaction sans bloquer les requêtes de lecture MVT en cours.
3. **Détection des tuiles expirées** :
   Imposm calcule quelles tuiles de niveau de zoom maximal (généralement zoom 14) sont traversées par les géométries modifiées, et écrit un fichier `.tiles`.
4. **Multiplication d'échelles & Invalidation** :
   L'utilitaire `tile_multiplier` calcule les tuiles parentes (zooms inférieurs 10 à 13) et Nginx purge ces clés précises de son cache.

---

## 2. Exécuter une Mise à Jour Manuelle

Pour déclencher une passe de mise à jour incrémentale :

```bash
./makina update
```

Le script :
- Vérifie s'il existe des diffs en attente pour votre zone.
- Injecte les modifications dans la base PostGIS.
- Purge automatiquement les tuiles concernées dans le cache Nginx.

---

## 3. Automatisation Périodique (Cron / Daemon)

Pour maintenir votre serveur à jour automatiquement, configurez une tâche planifiée dans le crontab de votre serveur :

```bash
crontab -e
```

Ajoutez par exemple une mise à jour toutes les 6 heures :
```cron
0 */6 * * * cd /chemin/vers/makina-maps && ./makina update >> /var/log/makina-update.log 2>&1
```

Ou une mise à jour quotidienne chaque nuit à 3h du matin :
```cron
0 3 * * * cd /chemin/vers/makina-maps && ./makina update >> /var/log/makina-update.log 2>&1
```

---

## 4. Purge Manuelle du Cache

Si vous souhaitez forcer le rafraîchissement complet du cache (par exemple après avoir modifié une fonction SQL ou un calque) :

```bash
# Purge complète du cache Nginx
./makina purge-cache
```

Ou purger sélectivement une zone ou un niveau de zoom particulier :
```bash
# Purge uniquement les tuiles du niveau de zoom 14
./makina purge-cache "14/"
```
