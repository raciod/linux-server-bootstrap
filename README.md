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

## Project Plan

**Scope (v1, locked):** SSH hardening + firewall, Docker + Compose deployment, systemd healthcheck timer, automatic security updates. Monitoring stack, fail2ban, backups, and CI are deliberately deferred to the roadmap.

**Repo structure:**
```
linux-server-bootstrap/
├── README.md
├── bootstrap.sh
├── config.env.example
├── systemd/
│   ├── healthcheck.service
│   └── healthcheck.timer
├── scripts/
│   └── healthcheck.sh
├── docker-compose.yml
└── docs/
    └── demo.gif
```

**Step 1 — Learn the basics**
Work through these on a throwaway VM before writing code. No time pressure — go at your own pace.
- Bash strict mode: http://redsymbol.net/articles/unofficial-bash-strict-mode/
- Google Shell Style Guide: https://google.github.io/styleguide/shellguide.html
- Initial Server Setup with Ubuntu: https://www.digitalocean.com/community/tutorials/initial-server-setup-with-ubuntu-22-04
- UFW Essentials: https://www.digitalocean.com/community/tutorials/ufw-essentials-common-firewall-rules-and-commands
- What is systemd?: https://www.digitalocean.com/community/tutorials/what-is-systemd
- Systemd Essentials (services/journal): https://www.digitalocean.com/community/tutorials/systemd-essentials-working-with-services-units-and-the-journal
- Understanding Systemd Units and Unit Files: https://www.digitalocean.com/community/tutorials/understanding-systemd-units-and-unit-files
- systemd.timer / systemd.service man pages: https://www.freedesktop.org/software/systemd/man/systemd.timer.html
- Docker Get Started: https://docs.docker.com/get-started/
- Docker Compose overview: https://docs.docker.com/compose/
- Ubuntu unattended-upgrades docs: https://ubuntu.com/server/docs/security-automatic-updates
- Checkpoint: explain the difference between a `.service` and a `.timer`, and what `ufw default deny incoming` does.

**Step 2 — Harden the server**
- Script skeleton: `set -euo pipefail`, `log()` function, `--dry-run` flag, `source config.env`
- `harden_ssh()`: back up `sshd_config`, disable root login + password auth, optional custom port, restart `sshd` only if changed
- `setup_firewall()`: check existing `ufw` rules before adding, default deny incoming, allow SSH/HTTP/HTTPS
- Test on throwaway VM; run twice to confirm idempotency
- Checkpoint: SSH key login works, root/password login fails, `ufw status verbose` shows exactly the expected ports

**Step 3 — Docker + self-healing**
- `install_docker()`: skip if already installed, add user to `docker` group, install Compose plugin
- Write `docker-compose.yml` (sample Nginx service, or one of your own past socket-based projects)
- Write `scripts/healthcheck.sh`: inspect container health, restart if down, log the event, always exit 0
- Write `systemd/healthcheck.service` (`Type=oneshot`) and `systemd/healthcheck.timer` (`OnBootSec=2min`, `OnUnitActiveSec=5min`)
- `setup_healthcheck_timer()`: copy units, `systemctl daemon-reload`, `enable --now`
- Checkpoint: killing the container manually results in it being back up within one timer interval, visible in `journalctl -u healthcheck.service`

**Step 4 — Auto-updates, polish, demo**
- `setup_auto_updates()`: install and configure `unattended-upgrades` for security-only patches
- Finalize `config.env.example` with comments for every variable
- Full clean run on a brand-new VM snapshot, then a second run to prove idempotency
- Record a terminal demo (asciinema or GIF): fresh VM → run script → verify firewall/Docker → kill container → watch it self-heal
- Push to GitHub with topics: `bash`, `sysadmin`, `docker`, `systemd`, `devops`, `linux`

**Troubleshooting notes**
- Always test SSH hardening changes in a second terminal session before closing the first — a bad `sshd_config` can lock you out.
- Cloud VM providers often have a separate network-level firewall; `ufw` alone won't open ports blocked at that layer.
- After adding a user to the `docker` group, that user must log out/in (or run `newgrp docker`) before it takes effect.
- After editing any unit file, run `systemctl daemon-reload` or systemd will keep using the cached version.

**Roadmap**
- fail2ban for brute-force protection
- Prometheus + node_exporter for metrics
- Automated backup/restore with a documented recovery procedure
- Vagrantfile + GitHub Actions CI to test the script on every push
