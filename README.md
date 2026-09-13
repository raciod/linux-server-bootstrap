# linux-server-bootstrap
A Bash script that automatically locks down and sets up a fresh Linux server — configuring the firewall, securing SSH access, installing Docker, and keeping services running automatically. Safe to run multiple times without breaking anything.

[English](#english) | [Français](#français)

---

## English

### Overview
This script takes a brand-new Linux server and turns it into a secure, ready-to-use machine in one step. It locks down remote access, sets up a firewall, installs Docker to run apps in containers, and adds a watchdog that automatically restarts any app that crashes.

> **Warning:** This script changes how you log in to the server (SSH) and blocks network traffic (firewall). Always test it on a virtual machine first, not a real server, in case something goes wrong.

### Key Features
* **Secures SSH access** — blocks root login and password logins, so only your private key can get in.
* **Sets up a firewall** — blocks all incoming traffic except what's needed (SSH, web).
* **Installs Docker** — so apps can run in isolated containers.
* **Self-healing** — checks every few minutes if the app is still running, and restarts it if it crashed.
* **Automatic security updates** — patches get installed on their own.
* **Safe to re-run** — running it again won't duplicate settings or break anything.

### Requirements
* A fresh Ubuntu or Debian server
* Root or `sudo` access
* An SSH key already set up on the server

### Usage
```bash
# Set your own username, port, etc.
cp config.env.example config.env
nano config.env

# See what the script would do, without changing anything
sudo ./bootstrap.sh --dry-run

# Run it for real
sudo ./bootstrap.sh

# Check that everything worked
sudo ufw status verbose
docker compose ps
systemctl status healthcheck.timer
```

### Known limitations
* SSH key installation is not automated — the script assumes a key is already authorized on the server before it disables password login. `SSH_KEY_PATH` in `config.env` is a placeholder for a future version that would handle this automatically.
* `healthcheck.service` currently hardcodes the `deploy` user's home directory. If you change `NEW_USER` in `config.env`, update the paths in `systemd/healthcheck.service` to match.

---

## Français

### Aperçu
Ce script prend un serveur Linux neuf et le transforme en machine sécurisée et prête à l'emploi en une seule étape. Il sécurise l'accès à distance, met en place un pare-feu, installe Docker pour faire tourner des applications dans des conteneurs, et ajoute une surveillance qui redémarre automatiquement toute application qui plante.

> **Attention :** Ce script modifie la façon de se connecter au serveur (SSH) et bloque du trafic réseau (pare-feu). Testez-le toujours sur une machine virtuelle d'abord, jamais sur un vrai serveur, au cas où quelque chose se passerait mal.

### Caractéristiques
* **Sécurise l'accès SSH** — bloque la connexion root et les mots de passe, seule votre clé privée fonctionne.
* **Met en place un pare-feu** — bloque tout le trafic entrant sauf ce qui est nécessaire (SSH, web).
* **Installe Docker** — pour faire tourner des applications dans des conteneurs isolés.
* **Auto-réparation** — vérifie toutes les quelques minutes si l'application tourne, et la redémarre si elle a planté.
* **Mises à jour automatiques** — les correctifs de sécurité s'installent tout seuls.
* **Peut être relancé sans risque** — le relancer ne duplique rien et ne casse rien.

### Prérequis
* Un serveur Ubuntu ou Debian neuf
* Accès Root ou `sudo`
* Une clé SSH déjà configurée sur le serveur

### Utilisation
```bash
# Définir votre utilisateur, port, etc.
cp config.env.example config.env
nano config.env

# Voir ce que le script ferait, sans rien modifier
sudo ./bootstrap.sh --dry-run

# Le lancer pour de vrai
sudo ./bootstrap.sh

# Vérifier que tout a fonctionné
sudo ufw status verbose
docker compose ps
systemctl status healthcheck.timer
```

---

**Repo structure:**
```
linux-server-bootstrap/
├── README.md
├── LICENSE
├── bootstrap.sh
├── config.env.example
├── .gitignore
├── systemd/
│   ├── healthcheck.service
│   └── healthcheck.timer
├── scripts/
│   └── healthcheck.sh
└── docker-compose.yml
```
