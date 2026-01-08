#!/bin/bash
# Script d'installation/mise à jour WOL NAS Listener pour Raspberry Pi
# Usage:
#   Installation : wget -qO- https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash
#   Mise à jour  : wget -qO- https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash -s -- --update

set -e

REPO_URL="https://github.com/venantvr/Rust.WOL.Services.git"
TMP_DIR="/tmp/wol-nas-install"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/wol-rust"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Vérifier les droits root
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en root (sudo)"
fi

# Mode update ?
UPDATE_MODE=false
if [ "$1" = "--update" ] || [ "$1" = "-u" ]; then
    UPDATE_MODE=true
    log_info "Mode mise à jour activé"
fi

# Détecter l'architecture
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armv7)
            echo "armv7"
            ;;
        *)
            log_error "Architecture non supportée: $arch (attendu: aarch64/arm64 ou armv7l)"
            ;;
    esac
}

# Fonction pour comparer les configs
compare_configs() {
    local old_config="$1"
    local new_config="$2"

    echo ""
    echo -e "${CYAN}=== Configuration actuelle ===${NC}"
    cat "$old_config"
    echo ""
    echo -e "${CYAN}=== Nouvelle configuration ===${NC}"
    cat "$new_config"
    echo ""

    # Demander confirmation
    echo -e "${YELLOW}Voulez-vous remplacer la configuration ? [o/N]${NC}"
    read -r response
    case "$response" in
        [oOyY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

ARCH=$(detect_arch)
log_info "Architecture détectée: $ARCH"

# Étape 1: Installer git si nécessaire
log_info "[1/6] Vérification de git..."
if ! command -v git &> /dev/null; then
    log_info "Installation de git..."
    apt-get update -qq
    apt-get install -y -qq git
else
    log_info "git déjà installé"
fi

# Étape 2: Cloner le repository
log_info "[2/6] Clonage du repository..."
rm -rf "$TMP_DIR"
git clone --depth 1 "$REPO_URL" "$TMP_DIR"

# Étape 3: Copier le binaire
log_info "[3/6] Installation du binaire ($ARCH)..."
BINARY="$TMP_DIR/bin/wol-nas-listener-$ARCH"
if [ ! -f "$BINARY" ]; then
    log_error "Binaire non trouvé: $BINARY"
fi

# Arrêter le service si actif (évite "Text file busy")
if systemctl is-active --quiet wol-nas.service 2>/dev/null; then
    log_info "Arrêt du service wol-nas.service..."
    systemctl stop wol-nas.service
fi

# Backup si mise à jour
if [ "$UPDATE_MODE" = true ] && [ -f "$INSTALL_DIR/wol-nas-listener" ]; then
    cp "$INSTALL_DIR/wol-nas-listener" "$INSTALL_DIR/wol-nas-listener.bak"
    log_info "Backup créé: $INSTALL_DIR/wol-nas-listener.bak"
fi

cp "$BINARY" "$INSTALL_DIR/wol-nas-listener"
chmod +x "$INSTALL_DIR/wol-nas-listener"

# Étape 4: Configuration
log_info "[4/6] Configuration..."
mkdir -p "$CONFIG_DIR"

if [ -f "$CONFIG_DIR/config.toml" ]; then
    if [ "$UPDATE_MODE" = true ]; then
        # Mode update : comparer et demander
        if compare_configs "$CONFIG_DIR/config.toml" "$TMP_DIR/config.toml"; then
            cp "$CONFIG_DIR/config.toml" "$CONFIG_DIR/config.toml.bak"
            cp "$TMP_DIR/config.toml" "$CONFIG_DIR/"
            log_info "Configuration mise à jour (backup: config.toml.bak)"
        else
            log_warn "Configuration conservée"
        fi
    else
        # Installation normale : conserver l'existante
        log_warn "Configuration existante conservée: $CONFIG_DIR/config.toml"
    fi
else
    cp "$TMP_DIR/config.toml" "$CONFIG_DIR/"
    log_info "Configuration par défaut installée dans $CONFIG_DIR/config.toml"
fi

# Étape 5: Service systemd
log_info "[5/6] Installation du service systemd..."
cp "$TMP_DIR/wol-nas.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable wol-nas.service

# Étape 6: Démarrage
log_info "[6/6] Redémarrage du service..."
systemctl restart wol-nas.service

# Nettoyage
rm -rf "$TMP_DIR"

# Résumé
echo ""
if [ "$UPDATE_MODE" = true ]; then
    echo -e "${GREEN}=== Mise à jour terminée ===${NC}"
else
    echo -e "${GREEN}=== Installation terminée ===${NC}"
fi
echo ""
echo "Binaire:       $INSTALL_DIR/wol-nas-listener"
echo "Configuration: $CONFIG_DIR/config.toml"
echo "Service:       wol-nas.service"
echo ""
echo "Commandes utiles:"
echo "  sudo systemctl status wol-nas.service       # Statut"
echo "  sudo journalctl -u wol-nas.service -f       # Logs"
echo "  sudo nano $CONFIG_DIR/config.toml           # Éditer config"
echo "  sudo systemctl restart wol-nas.service      # Redémarrer"
echo "  sudo wol-nas-listener --shutdown            # Extinction manuelle"
echo ""
echo "Cron (extinction programmée):"
echo "  sudo crontab -e"
echo "  0 2 * * * /usr/local/bin/wol-nas-listener --shutdown"
echo ""

# Afficher le statut
systemctl status wol-nas.service --no-pager || true
