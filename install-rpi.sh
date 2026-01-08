#!/bin/bash
# Script d'installation pour Raspberry Pi
# Usage: ./install-rpi.sh

set -e

echo "=== Installation WOL NAS Listener ==="

# Vérifier si Rust est installé
if ! command -v cargo &> /dev/null; then
    echo "[1/5] Installation de Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
else
    echo "[1/5] Rust déjà installé"
fi

# Compilation
echo "[2/5] Compilation..."
cargo build --release

# Création du répertoire de configuration
echo "[3/5] Création de /etc/wol-rust..."
sudo mkdir -p /etc/wol-rust

# Copie des fichiers
echo "[4/5] Installation des fichiers..."
sudo cp target/release/wol-nas-listener /usr/local/bin/
sudo cp config.toml /etc/wol-rust/
sudo cp wol-nas.service /etc/systemd/system/

# Activation du service
echo "[5/5] Activation du service..."
sudo systemctl daemon-reload
sudo systemctl enable --now wol-nas.service

echo ""
echo "=== Installation terminée ==="
echo "Vérifier le statut: sudo systemctl status wol-nas.service"
echo "Voir les logs: sudo journalctl -u wol-nas.service -f"
