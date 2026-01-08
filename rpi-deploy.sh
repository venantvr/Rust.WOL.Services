#!/bin/bash
# Script d'installation WOL NAS Listener pour Raspberry Pi
# Usage: curl -sSL https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash
#    ou: wget -qO- https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash

set -e

REPO_URL="https://github.com/venantvr/Rust.WOL.Services.git"
TMP_DIR="/tmp/wol-nas-install"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/wol-rust"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Vérifier les droits root
if [ "$EUID" -ne 0 ]; then
    log_error "Ce script doit être exécuté en root (sudo)"
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
cp "$BINARY" "$INSTALL_DIR/wol-nas-listener"
chmod +x "$INSTALL_DIR/wol-nas-listener"

# Étape 4: Configuration
log_info "[4/6] Configuration..."
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_DIR/config.toml" ]; then
    cp "$TMP_DIR/config.toml" "$CONFIG_DIR/"
    log_info "Configuration par défaut installée dans $CONFIG_DIR/config.toml"
else
    log_warn "Configuration existante conservée: $CONFIG_DIR/config.toml"
fi

# Étape 5: Service systemd
log_info "[5/6] Installation du service systemd..."
cp "$TMP_DIR/wol-nas.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable wol-nas.service

# Étape 6: Démarrage
log_info "[6/6] Démarrage du service..."
systemctl restart wol-nas.service

# Nettoyage
rm -rf "$TMP_DIR"

# Résumé
echo ""
echo -e "${GREEN}=== Installation terminée ===${NC}"
echo ""
echo "Binaire:       $INSTALL_DIR/wol-nas-listener"
echo "Configuration: $CONFIG_DIR/config.toml"
echo "Service:       wol-nas.service"
echo ""
echo "Commandes utiles:"
echo "  sudo systemctl status wol-nas.service    # Statut"
echo "  sudo journalctl -u wol-nas.service -f    # Logs"
echo "  sudo nano $CONFIG_DIR/config.toml        # Éditer config"
echo "  sudo systemctl restart wol-nas.service   # Redémarrer"
echo ""

# Afficher le statut
systemctl status wol-nas.service --no-pager || true
