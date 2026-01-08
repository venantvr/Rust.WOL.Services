# WOL NAS Listener

Écouteur Wake-on-LAN en Rust pour Raspberry Pi. Détecte les paquets magiques UDP et démarre automatiquement les services configurés.

---

## Installation rapide (Raspberry Pi)

> **Une seule commande pour tout installer :**
>
> ```bash
> wget -qO- https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash
> ```

<details>
<summary>Alternative avec curl</summary>

```bash
curl -sSL https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash
```
</details>

---

Le script détecte automatiquement l'architecture (ARM64 ou ARMv7), installe git si nécessaire, et configure le service systemd.

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

## Test & Debug

### Sur le Raspberry Pi (voir les logs)

```bash
# Logs en temps réel (mode tail)
sudo journalctl -u wol-nas.service -f
```

### Depuis Ubuntu (envoyer le magic packet)

```bash
# Installer wakeonlan
sudo apt install wakeonlan

# Envoyer le paquet à l'IP directe du RPi (recommandé)
wakeonlan -i <IP_RPI> -p 9 <MAC_RPI>

# Exemple :
wakeonlan -i 192.168.1.191 -p 9 DC:A6:32:77:89:63
```

> **Note** : L'envoi en broadcast (`192.168.1.255`) peut être bloqué par certains routeurs. Préférez l'IP directe du RPi.

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
