# Guide de Déploiement en Production

Ce document rassemble les recommandations pour déployer, sécuriser et superviser Makina Maps en environnement de production à haute disponibilité.

---

## 1. Architecture Recommandée

En production, Makina Maps se place derrière un Reverse Proxy frontal (NGINX hôte, Traefik, Caddy ou Cloudflare) assurant la terminaison SSL/TLS (HTTPS) :

```text
INTERNET (HTTPS :443)
       │
       ▼
[Reverse Proxy Hôte / Traefik / Nginx avec Certificat Let's Encrypt]
       │
       ▼ (HTTP :8080 en réseau interne ou socket)
[Conteneur Nginx Makina Maps]
       ├── Cache NVMe local (50 à 200 Go)
       ├── Rate Limiting
       └── Proxy vers Postserve & TileServer-GL
```

---

## 2. Réglages Essentiels (.env)

Pour déployer avec votre domaine public (ex: `https://tiles.mon-domaine.fr`), ajustez les variables suivantes dans votre fichier `.env` :

```bash
# 1. URL publique HTTPS (utilisée par TileJSON data/v3.json pour annoncer les URLs des tuiles)
OMT_HOST=https://tiles.mon-domaine.fr

# 2. Ports internes
# Le frontal Nginx Makina Maps est exposé sur 127.0.0.1:8080 pour le reverse proxy
PORT=8080

# 3. Sécurité de la base de données
POSTGRES_DB=openmaptiles
POSTGRES_USER=openmaptiles
POSTGRES_PASSWORD=un_mot_de_passe_robuste_et_aleatoire

# 4. Dimensionnement du cache Nginx
# Adapter à l'espace disque NVMe/SSD disponible (ex: 50g à 200g)
CACHE_MAX_SIZE=50g
CACHE_KEYS_ZONE_SIZE=100m
```

> [!IMPORTANT]
> **Port de debug `8090` :** En production, fermez le port 8090 de l'extérieur. Dans `docker-compose.yml`, retirez le mappage direct `ports: - "8090:8090"` ou remplacez-le par `127.0.0.1:8090:8090`. Seul le port 80 de Nginx doit être ciblé par votre reverse proxy.

---

## 3. Configuration Systemd (Démarrage Automatique)

Pour garantir que la stack redémarre automatiquement après un reboot de la machine hôte :

Créez le fichier de service `/etc/systemd/system/makina-maps.service` :

```ini
[Unit]
Description=Makina Maps Vector Tiles Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/makina-maps
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose stop
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Activez et démarrez le service :
```bash
sudo systemctl daemon-reload
sudo systemctl enable makina-maps
sudo systemctl start makina-maps
```

---

## 4. Configuration Reverse Proxy HTTPS

Le conteneur Nginx interne de Makina Maps réécrit dynamiquement les URLs de styles (`style.json`) et du visualiseur web en fonction de l'en-tête `X-Forwarded-Proto` et du domaine public.

### A. Avec Nginx Hôte (Let's Encrypt / Certbot)

```nginx
server {
    listen 80;
    server_name tiles.mon-domaine.fr;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    server_name tiles.mon-domaine.fr;

    ssl_certificate /etc/letsencrypt/live/tiles.mon-domaine.fr/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/tiles.mon-domaine.fr/privkey.pem;

    # Protocoles modernes
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;

        # Streaming et timeouts adaptés aux tuiles
        proxy_buffering off;
        proxy_read_timeout 60s;
    }
}
```

### B. Avec Traefik v2/v3 (Labels Docker)

Ajoutez directement sur le service `nginx` de `docker-compose.yml` :

```yaml
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.makinamaps.rule=Host(`tiles.mon-domaine.fr`)"
      - "traefik.http.routers.makinamaps.entrypoints=websecure"
      - "traefik.http.routers.makinamaps.tls.certresolver=letsencrypt"
      - "traefik.http.services.makinamaps.loadbalancer.server.port=80"
```

### C. Avec Caddy Server

```caddy
tiles.mon-domaine.fr {
    reverse_proxy 127.0.0.1:8080 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-Proto https
    }
}
```

---

## 5. Monitoring et Métriques

### A. État de NGINX
L'état des connexions actives et requêtes/seconde est exposé sur le port interne `8082` :
```bash
curl http://localhost:8082/nginx_status
```

Exemple de réponse :
```text
Active connections: 42 
server accepts handled requests
 145020 145020 289045 
Reading: 0 Writing: 4 Waiting: 38 
```

### B. Intégration Prometheus
Vous pouvez surveiller :
- Le taux de HIT/MISS du cache via [nginx-prometheus-exporter](https://github.com/nginxinc/nginx-prometheus-exporter).
- Les performances PostgreSQL avec `postgres_exporter`.

---

## 6. Sauvegarde & Plan de Reprise d'Activité (PRA)

- **Schémas et configurations** : Le répertoire entier de configuration et les styles (`styles/`, `schema/`, `config/`) doivent être versionnés sous Git.
- **Base de données** : Grâce au script `./makina download` et `./makina import`, vous pouvez réinitialiser et reconstruire l'intégralité d'un nœud en quelques minutes à partir des fichiers PBF sources d'OpenStreetMap.
