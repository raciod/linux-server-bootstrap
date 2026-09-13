#!/usr/bin/env bash
#
# bootstrap.sh — linux-server-bootstrap
#
# Idempotent server hardening + deployment script.
# Hardens SSH, configures the firewall, installs Docker, deploys a sample
# service, sets up a self-healing systemd timer, and confirms automatic
# security updates are enabled.
#
# Usage:
#   sudo ./bootstrap.sh              # run for real
#   sudo ./bootstrap.sh --dry-run    # show what would happen, change nothing

set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Globals
# ---------------------------------------------------------------------------

LOG_FILE="/var/log/bootstrap.log"
DRY_RUN=false

# ---------------------------------------------------------------------------
# log: print a timestamped message to stdout AND append it to LOG_FILE
# ---------------------------------------------------------------------------
log() {
  local msg="$1"
  local timestamped_msg="[$(date '+%Y-%m-%d %H:%M:%S')] ${msg}"

  echo "${timestamped_msg}"
  echo "${timestamped_msg}" >> "${LOG_FILE}"
}

# ---------------------------------------------------------------------------
# run: execute a command normally, or just log it if DRY_RUN is true
# Usage: run cp file1 file2
# Note: doesn't work for commands using shell redirection (>>, |) — those
# are handled with manual if/else blocks instead (see harden_ssh,
# setup_auto_updates, deploy_service, install_docker).
# ---------------------------------------------------------------------------
run() {
  if [ "${DRY_RUN}" = true ]; then
    log "[DRY RUN] would run: $*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
# parse_args: handle --dry-run flag
# ---------------------------------------------------------------------------
parse_args() {
  for var in "$@"; do
    if [[ "$var" = "--dry-run" ]]; then
      DRY_RUN=true
    fi
  done
}

# ---------------------------------------------------------------------------
# load_config: source config.env, error out clearly if it's missing
# ---------------------------------------------------------------------------
load_config() {
  local script_dir
  script_dir="$(dirname "$(readlink -f "$0")")"
  local config_path="${script_dir}/config.env"

  if [ -e "${config_path}" ]; then
    source "${config_path}"
  else
    log "config.env doesn't exist at ${config_path}"
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# harden_ssh: disable root login + password auth, optional custom port
# ---------------------------------------------------------------------------
harden_ssh() {
  local sshd_config="/etc/ssh/sshd_config"
  local cloud_init_config="/etc/ssh/sshd_config.d/50-cloud-init.conf"

  # --- back up both files, only if a backup doesn't already exist ---
  if [ -f "${sshd_config}" ] && [ ! -f "${sshd_config}.bak" ]; then
    run cp "${sshd_config}" "${sshd_config}.bak"
    log "Backed up ${sshd_config}"
  fi
  if [ -f "${cloud_init_config}" ] && [ ! -f "${cloud_init_config}.bak" ]; then
    run cp "${cloud_init_config}" "${cloud_init_config}.bak"
    log "Backed up ${cloud_init_config}"
  fi

  if [ "${DRY_RUN}" = true ]; then
    log "[DRY RUN] would edit ${sshd_config} and ${cloud_init_config} (PermitRootLogin, PasswordAuthentication, Port)"
    log "[DRY RUN] would restart ssh service if changes were needed"
    return
  fi

  # --- capture a snapshot of both files before editing (idempotency check) ---
  local before
  before="$(cat "${sshd_config}" "${cloud_init_config}" 2>/dev/null || true)"

  # --- edit the main sshd_config ---
  if grep -q "^PermitRootLogin" "${sshd_config}"; then
    sed -i "s/^PermitRootLogin.*/PermitRootLogin no/" "${sshd_config}"
  else
    echo "PermitRootLogin no" >> "${sshd_config}"
  fi

  if grep -q "^PasswordAuthentication" "${sshd_config}"; then
    sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" "${sshd_config}"
  else
    echo "PasswordAuthentication no" >> "${sshd_config}"
  fi

  if [ "${SSH_PORT}" != "22" ]; then
    if grep -q "^Port" "${sshd_config}"; then
      sed -i "s/^Port.*/Port ${SSH_PORT}/" "${sshd_config}"
    else
      echo "Port ${SSH_PORT}" >> "${sshd_config}"
    fi
  fi

  # --- also patch the cloud-init override file, if it exists (a real Ubuntu
  # gotcha: this file can silently override PasswordAuthentication above) ---
  if [ -f "${cloud_init_config}" ]; then
    if grep -q "^PasswordAuthentication" "${cloud_init_config}"; then
      sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" "${cloud_init_config}"
    fi
  fi

  # --- only restart sshd if something actually changed ---
  local after
  after="$(cat "${sshd_config}" "${cloud_init_config}" 2>/dev/null || true)"

  if [ "${before}" != "${after}" ]; then
    log "sshd_config changed, restarting ssh service"
    systemctl restart ssh
  else
    log "sshd_config already hardened, no restart needed"
  fi
}

# ---------------------------------------------------------------------------
# setup_firewall: configure ufw — default deny incoming, allow SSH/HTTP/HTTPS
# ---------------------------------------------------------------------------
setup_firewall() {
  # allow SSH FIRST, always, before enabling — a locked-out SSH session is
  # the single most common mistake when scripting firewall setup
  run ufw allow "${SSH_PORT}/tcp"
  run ufw allow 80/tcp
  run ufw allow 443/tcp

  run ufw default deny incoming
  run ufw default allow outgoing

  # --force avoids the interactive y/n prompt so the script can run unattended
  run ufw --force enable

  log "Firewall configured: default deny incoming, allow ${SSH_PORT}/80/443"
}

# ---------------------------------------------------------------------------
# install_docker: install Docker Engine + Compose plugin, add user to group
# ---------------------------------------------------------------------------
install_docker() {
  if command -v docker &> /dev/null; then
    log "Docker already installed, skipping"
  else
    log "Installing Docker..."
    if [ "${DRY_RUN}" = true ]; then
      log "[DRY RUN] would download and run get-docker.sh"
    else
      curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
      sh /tmp/get-docker.sh
      rm -f /tmp/get-docker.sh
    fi
  fi

  if ! id -nG "${NEW_USER}" | grep -qw docker; then
    run usermod -aG docker "${NEW_USER}"
    log "Added ${NEW_USER} to the docker group (they'll need to re-login)"
  fi
}

# ---------------------------------------------------------------------------
# deploy_service: copy docker-compose.yml into place and bring it up
# ---------------------------------------------------------------------------
deploy_service() {
  local script_dir
  script_dir="$(dirname "$(readlink -f "$0")")"
  local user_home
  user_home="$(getent passwd "${NEW_USER}" | cut -d: -f6)"

  run cp "${script_dir}/docker-compose.yml" "${user_home}/docker-compose.yml"
  run chown "${NEW_USER}:${NEW_USER}" "${user_home}/docker-compose.yml"

  if [ "${DRY_RUN}" = true ]; then
    log "[DRY RUN] would run: docker compose up -d (as ${NEW_USER}, in ${user_home})"
  else
    su - "${NEW_USER}" -c "cd '${user_home}' && docker compose up -d"
  fi

  log "Deployed ${CONTAINER_NAME} via docker compose"
}

# ---------------------------------------------------------------------------
# setup_healthcheck_timer: install healthcheck.sh + its systemd units
# ---------------------------------------------------------------------------
setup_healthcheck_timer() {
  local script_dir
  script_dir="$(dirname "$(readlink -f "$0")")"
  local user_home
  user_home="$(getent passwd "${NEW_USER}" | cut -d: -f6)"

  run cp "${script_dir}/scripts/healthcheck.sh" "${user_home}/healthcheck.sh"
  run chown "${NEW_USER}:${NEW_USER}" "${user_home}/healthcheck.sh"
  run chmod +x "${user_home}/healthcheck.sh"

  run cp "${script_dir}/systemd/healthcheck.service" /etc/systemd/system/healthcheck.service
  run cp "${script_dir}/systemd/healthcheck.timer" /etc/systemd/system/healthcheck.timer

  run systemctl daemon-reload
  run systemctl enable --now healthcheck.timer

  log "Healthcheck timer installed and running (every ${HEALTHCHECK_MIN} min)"
}

# ---------------------------------------------------------------------------
# setup_auto_updates: confirm/enable unattended-upgrades
# ---------------------------------------------------------------------------
setup_auto_updates() {
  if ! dpkg -l | grep -q unattended-upgrades; then
    run apt-get install -y unattended-upgrades
    log "Installed unattended-upgrades"
  fi

  local auto_upgrades_file="/etc/apt/apt.conf.d/20auto-upgrades"

  if [ "${DRY_RUN}" = true ]; then
    log "[DRY RUN] would write Periodic::Update-Package-Lists and Unattended-Upgrade lines to ${auto_upgrades_file}"
  else
    cat > "${auto_upgrades_file}" <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF
  fi

  log "Automatic security updates confirmed enabled"
}

# ---------------------------------------------------------------------------
# main: run everything in order
# ---------------------------------------------------------------------------
main() {
  parse_args "$@"
  load_config
  log "Starting bootstrap... (DRY_RUN=${DRY_RUN})"

  harden_ssh
  setup_firewall
  install_docker
  deploy_service
  setup_healthcheck_timer
  setup_auto_updates

  log "Bootstrap complete."
}

main "$@"
