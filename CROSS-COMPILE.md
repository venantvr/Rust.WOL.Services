# Cross-compilation Rust pour Raspberry Pi

Guide complet pour compiler du code Rust sur Ubuntu/Linux x86-64 pour Raspberry Pi (ARM).

---

## Pourquoi cross-compiler ?

- **Rapide** : Compilation en secondes sur un PC moderne vs plusieurs minutes sur RPi
- **Pratique** : Pas besoin d'installer Rust sur le RPi
- **CI/CD** : Intégration facile dans des pipelines de build

---

## Prérequis

### 1. Installer Rust

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env
```

### 2. Ajouter les targets ARM

```bash
# Raspberry Pi 64-bit (RPi 3, 4, 5 avec OS 64-bit)
rustup target add aarch64-unknown-linux-gnu

# Raspberry Pi 32-bit (RPi Zero, 1, 2, ou OS 32-bit)
rustup target add armv7-unknown-linux-gnueabihf
```

### 3. Installer les cross-compilateurs (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install -y gcc-aarch64-linux-gnu gcc-arm-linux-gnueabihf
```

---

## Configuration

Créer `.cargo/config.toml` à la racine du projet :

```toml
[target.aarch64-unknown-linux-gnu]
linker = "aarch64-linux-gnu-gcc"

[target.armv7-unknown-linux-gnueabihf]
linker = "arm-linux-gnueabihf-gcc"
```

---

## Compilation

### Raspberry Pi 64-bit (aarch64)

```bash
cargo build --release --target aarch64-unknown-linux-gnu
```

Binaire généré : `target/aarch64-unknown-linux-gnu/release/<nom_projet>`

### Raspberry Pi 32-bit (armv7)

```bash
cargo build --release --target armv7-unknown-linux-gnueabihf
```

Binaire généré : `target/armv7-unknown-linux-gnueabihf/release/<nom_projet>`

---

## Déploiement

### Méthode simple (scp)

```bash
# 64-bit
scp target/aarch64-unknown-linux-gnu/release/mon-programme pi@192.168.1.100:~/

# 32-bit
scp target/armv7-unknown-linux-gnueabihf/release/mon-programme pi@192.168.1.100:~/
```

### Exécution sur le RPi

```bash
ssh pi@192.168.1.100
chmod +x ~/mon-programme
./mon-programme
```

---

## Vérification du binaire

```bash
# Vérifier l'architecture du binaire
file target/aarch64-unknown-linux-gnu/release/mon-programme
# Sortie attendue : ELF 64-bit LSB pie executable, ARM aarch64...

file target/armv7-unknown-linux-gnueabihf/release/mon-programme
# Sortie attendue : ELF 32-bit LSB pie executable, ARM, EABI5...
```

---

## Quelle architecture choisir ?

| Raspberry Pi | Architecture | Target |
|--------------|--------------|--------|
| RPi 5, 4, 3 (64-bit OS) | ARM64 | `aarch64-unknown-linux-gnu` |
| RPi 4, 3, 2 (32-bit OS) | ARMv7 | `armv7-unknown-linux-gnueabihf` |
| RPi Zero 2 W (64-bit) | ARM64 | `aarch64-unknown-linux-gnu` |
| RPi Zero, Zero W, 1 | ARMv6 | `arm-unknown-linux-gnueabihf` * |

> \* ARMv6 nécessite une configuration supplémentaire avec `cross` ou `cargo-zigbuild`

### Vérifier l'architecture sur le RPi

```bash
uname -m
# aarch64 = 64-bit (ARM64)
# armv7l  = 32-bit (ARMv7)
# armv6l  = 32-bit (ARMv6, RPi Zero/1)
```

---

## Troubleshooting

### Erreur : linker not found

```
error: linker `aarch64-linux-gnu-gcc` not found
```

**Solution** : Installer le cross-compilateur

```bash
sudo apt install gcc-aarch64-linux-gnu   # pour ARM64
sudo apt install gcc-arm-linux-gnueabihf # pour ARMv7
```

### Erreur : cannot find crti.o

```
cannot find crti.o: No such file or directory
```

**Solution** : Installer les libc de développement

```bash
sudo apt install libc6-dev-arm64-cross    # pour ARM64
sudo apt install libc6-dev-armhf-cross    # pour ARMv7
```

### Le binaire ne s'exécute pas sur le RPi

Vérifiez que l'architecture correspond :

```bash
# Sur le RPi
uname -m

# Sur votre machine de dev
file target/*/release/mon-programme
```

---

## Automatisation avec script

Exemple de script de build + déploiement :

```bash
#!/bin/bash
set -e

RPI_IP="${1:-192.168.1.100}"
ARCH="${2:-64}"
PROJECT_NAME="mon-programme"

if [ "$ARCH" = "64" ]; then
    TARGET="aarch64-unknown-linux-gnu"
else
    TARGET="armv7-unknown-linux-gnueabihf"
fi

echo "=== Compilation pour $TARGET ==="
cargo build --release --target $TARGET

echo "=== Déploiement vers $RPI_IP ==="
scp "target/$TARGET/release/$PROJECT_NAME" "pi@$RPI_IP:~/"

echo "=== Terminé ==="
```

---

## Ressources

- [Rust Platform Support](https://doc.rust-lang.org/nightly/rustc/platform-support.html)
- [Cross-compilation with Cargo](https://rust-lang.github.io/rustup/cross-compilation.html)
- [cross - Zero setup cross compilation](https://github.com/cross-rs/cross)
