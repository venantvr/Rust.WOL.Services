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

### Mise à jour

Pour mettre à jour le binaire (conserve la config existante) :

```bash
wget -qO- https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash -s -- --update
```

### Forcer la mise à jour de la configuration

Pour remplacer la configuration par celle du repo (sans confirmation) :

```bash
wget -qO- https://raw.githubusercontent.com/venantvr/Rust.WOL.Services/master/rpi-deploy.sh | sudo bash -s -- --force-config
```

> **Note** : Les deux options peuvent être combinées : `--update --force-config`

---

Le script détecte automatiquement l'architecture (ARM64 ou ARMv7), installe git si nécessaire, et configure le service systemd.

## Fonctionnalités

- **WOL Listener** : Écoute des paquets UDP (Magic Packet) et démarrage automatique des services
- **Shutdown** : Extinction propre du NAS via cron (arrêt Docker, services, sync)
- Auto-détection de l'adresse MAC via `/sys/class/net/`
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
    "vsftpd"
]

[shutdown]
poweroff = true        # Éteindre la machine (false = services seulement)
delay_minutes = 5      # Délai avant extinction (si poweroff = true)
docker_stop = true     # Arrêter les conteneurs Docker
unexport_nfs = true    # Désactiver les exports NFS
```

## Utilisation

### Mode WOL (par défaut)

Le service systemd écoute en permanence les paquets WOL :

```bash
# Statut du service
sudo systemctl status wol-nas.service

# Logs en temps réel
sudo journalctl -u wol-nas.service -f

# Redémarrer après modification de la config
sudo systemctl restart wol-nas.service
```

### Mode Shutdown (extinction programmée)

Lancer manuellement :

```bash
sudo /usr/local/bin/wol-nas-listener --shutdown
```

La séquence d'arrêt :
1. Programme `shutdown +5` (si `poweroff = true`)
2. Arrête les conteneurs Docker (si `docker_stop = true`)
3. Stoppe les services (liste `services`)
4. Unexport NFS (si `unexport_nfs = true`)
5. Sync des caches

### Configuration Cron (extinction automatique)

Pour programmer une extinction automatique (ex: tous les jours à 2h) :

```bash
# Éditer le crontab root
sudo crontab -e
```

Ajouter la ligne :

```cron
# Extinction NAS à 2h du matin
0 2 * * * /usr/local/bin/wol-nas-listener --shutdown >> /var/log/wol-shutdown.log 2>&1
```

**Format cron** : `minute heure jour mois jour_semaine commande`

| Exemple | Description |
|---------|-------------|
| `0 2 * * *` | Tous les jours à 2h00 |
| `0 23 * * 1-5` | Du lundi au vendredi à 23h00 |
| `30 1 * * 0` | Dimanche à 1h30 |
| `0 */6 * * *` | Toutes les 6 heures |

**Vérifier le crontab** :

```bash
sudo crontab -l
```

**Consulter les logs** :

```bash
cat /var/log/wol-shutdown.log
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
├── rpi-deploy.sh       # Script d'installation/mise à jour RPi
├── bin/                # Binaires pré-compilés ARM
│   ├── wol-nas-listener-arm64
│   └── wol-nas-listener-armv7
└── CROSS-COMPILE.md    # Guide de cross-compilation
```

## Licence

MIT
