#!/bin/bash
# Script de déploiement vers Raspberry Pi
# Usage: ./deploy-rpi.sh <IP_RPI> [32|64]

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <IP_RPI> [32|64]"
    echo "  IP_RPI : Adresse IP du Raspberry Pi"
    echo "  32|64  : Architecture (défaut: 64)"
    exit 1
fi

RPI_IP="$1"
ARCH="${2:-64}"
RPI_USER="pi"

if [ "$ARCH" = "32" ]; then
    BINARY="target/armv7-unknown-linux-gnueabihf/release/wol-nas-listener"
    echo "=== Déploiement ARMv7 (32-bit) vers $RPI_IP ==="
else
    BINARY="target/aarch64-unknown-linux-gnu/release/wol-nas-listener"
    echo "=== Déploiement ARM64 (64-bit) vers $RPI_IP ==="
fi

# Vérifier que le binaire existe
if [ ! -f "$BINARY" ]; then
    echo "Erreur: Binaire non trouvé: $BINARY"
    echo "Lancez d'abord la compilation cross-platform"
    exit 1
fi

echo "[1/5] Transfert du binaire..."
scp "$BINARY" "${RPI_USER}@${RPI_IP}:~/wol-nas-listener"

echo "[2/5] Transfert des fichiers de configuration..."
scp config.toml wol-nas.service "${RPI_USER}@${RPI_IP}:~/"

echo "[3/5] Installation sur le RPi..."
ssh "${RPI_USER}@${RPI_IP}" << 'EOF'
set -e
sudo mkdir -p /etc/wol-rust
sudo cp ~/wol-nas-listener /usr/local/bin/
sudo chmod +x /usr/local/bin/wol-nas-listener
sudo cp ~/config.toml /etc/wol-rust/
sudo cp ~/wol-nas.service /etc/systemd/system/
rm ~/wol-nas-listener ~/config.toml ~/wol-nas.service
EOF

echo "[4/5] Activation du service..."
ssh "${RPI_USER}@${RPI_IP}" << 'EOF'
sudo systemctl daemon-reload
sudo systemctl enable wol-nas.service
sudo systemctl restart wol-nas.service
EOF

echo "[5/5] Vérification du statut..."
ssh "${RPI_USER}@${RPI_IP}" "sudo systemctl status wol-nas.service --no-pager"

echo ""
echo "=== Déploiement terminé ==="
echo "Voir les logs: ssh ${RPI_USER}@${RPI_IP} 'sudo journalctl -u wol-nas.service -f'"
