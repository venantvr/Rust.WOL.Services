# WOL NAS Listener

Écouteur Wake-on-LAN en Rust pour Raspberry Pi. Détecte les paquets magiques UDP et démarre automatiquement les services configurés.

## Fonctionnalités

- Auto-détection de l'adresse MAC via `/sys/class/net/`
- Écoute des paquets UDP (Magic Packet)
- Démarrage automatique des services systemd
- Configuration TOML externe

## Prérequis

- Raspberry Pi (32-bit ou 64-bit)
- Rust (pour compilation locale) ou binaire pré-compilé

## Installation

### Option 1 : Déploiement depuis une machine de développement

```bash
# Cross-compiler
cargo build --release --target aarch64-unknown-linux-gnu    # RPi 64-bit
cargo build --release --target armv7-unknown-linux-gnueabihf # RPi 32-bit

# Déployer
./deploy-rpi.sh <IP_RPI> [32|64]
```

### Option 2 : Compilation sur le Raspberry Pi

```bash
# Transférer le projet
scp -r . pi@<IP_RPI>:~/wol-nas-listener/

# Sur le RPi
cd ~/wol-nas-listener
./install-rpi.sh
```

## Configuration

Éditer `/etc/wol-rust/config.toml` :

```toml
interface = "eth0"
port = 9
services = [
    "docker",
    "nfs-kernel-server",
    "vsftpd",
    "minidlna"
]
```

## Utilisation

```bash
# Statut du service
sudo systemctl status wol-nas.service

# Logs en temps réel
sudo journalctl -u wol-nas.service -f

# Redémarrer après modification de la config
sudo systemctl restart wol-nas.service
```

## Test

Depuis un terminal Ubuntu :

```bash
# Installer wakeonlan
sudo apt install wakeonlan

# Envoyer un paquet magique
wakeonlan -i 192.168.1.255 -p 9 XX:XX:XX:XX:XX:XX
```

## Structure du projet

```
├── src/main.rs         # Code source
├── Cargo.toml          # Dépendances
├── config.toml         # Configuration
├── wol-nas.service     # Service systemd
├── deploy-rpi.sh       # Script de déploiement
└── install-rpi.sh      # Script d'installation sur RPi
```

## Licence

MIT
