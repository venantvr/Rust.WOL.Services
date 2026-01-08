use std::env;
use std::fs;
use std::net::UdpSocket;
use std::process::Command;
use serde::Deserialize;

#[derive(Deserialize)]
struct Config {
    interface: String,
    port: u16,
    services: Vec<String>,
    #[serde(default)]
    shutdown: ShutdownConfig,
}

#[derive(Deserialize, Default)]
struct ShutdownConfig {
    #[serde(default = "default_delay")]
    delay_minutes: u32,
    #[serde(default)]
    docker_stop: bool,
    #[serde(default)]
    unexport_nfs: bool,
}

fn default_delay() -> u32 { 5 }

fn get_mac_address(interface: &str) -> Option<[u8; 6]> {
    let path = format!("/sys/class/net/{}/address", interface);
    let mac_str = fs::read_to_string(path).ok()?;
    let hex_values: Vec<u8> = mac_str.trim().split(':')
        .map(|s| u8::from_str_radix(s, 16).unwrap_or(0))
        .collect();

    let mut mac = [0u8; 6];
    if hex_values.len() == 6 {
        mac.copy_from_slice(&hex_values);
        Some(mac)
    } else {
        None
    }
}

fn run_shutdown(config: &Config) -> std::io::Result<()> {
    let delay = config.shutdown.delay_minutes;

    println!("=== Séquence d'arrêt du NAS (délai: {}min) ===", delay);

    // 1. Programmer l'extinction
    println!("[1/4] Programmation de l'extinction...");
    let shutdown_msg = format!("Arrêt du NAS programmé. Fermeture des services en cours...");
    Command::new("shutdown")
        .args([&format!("+{}", delay), &shutdown_msg])
        .status()?;

    // 2. Arrêt des conteneurs Docker
    if config.shutdown.docker_stop {
        println!("[2/4] Arrêt des conteneurs Docker...");
        let output = Command::new("docker")
            .args(["ps", "-q"])
            .output()?;

        let containers = String::from_utf8_lossy(&output.stdout);
        if !containers.trim().is_empty() {
            for container_id in containers.trim().lines() {
                let status = Command::new("docker")
                    .args(["stop", container_id])
                    .status()?;
                println!("  -> Container {} : {}",
                    &container_id[..12.min(container_id.len())],
                    if status.success() { "OK" } else { "Erreur" });
            }
        } else {
            println!("  -> Aucun conteneur actif");
        }
    } else {
        println!("[2/4] Docker skip (désactivé dans config)");
    }

    // 3. Arrêt des services
    println!("[3/4] Arrêt des services...");
    for service in &config.services {
        let status = Command::new("systemctl")
            .args(["stop", service])
            .status()?;
        println!("  -> {} : {}", service, if status.success() { "OK" } else { "Erreur" });
    }

    // Unexport NFS si activé
    if config.shutdown.unexport_nfs {
        println!("  -> Unexport NFS...");
        Command::new("exportfs").arg("-au").status()?;
    }

    // 4. Sync final
    println!("[4/4] Synchronisation des caches...");
    Command::new("sync").status()?;

    println!("");
    println!("=== Arrêt programmé dans {} minutes ===", delay);
    println!("La LED verte clignotera 10 fois avant extinction.");

    Ok(())
}

fn run_wol_listener(config: &Config) -> std::io::Result<()> {
    let my_mac = get_mac_address(&config.interface)
        .expect("Impossible de lire l'adresse MAC");

    let socket = UdpSocket::bind(format!("0.0.0.0:{}", config.port))?;
    println!("Écouteur WOL Rust actif sur {} (MAC: {:02X?})", config.interface, my_mac);

    let mut buf = [0; 1024];
    loop {
        let (amt, _) = socket.recv_from(&mut buf)?;

        // Vérification Magic Packet (6x 0xFF + 16x MAC)
        if amt >= 102 {
            let header_ok = &buf[0..6] == &[0xFF; 6];
            let mac_ok = &buf[6..12] == &my_mac;

            if header_ok && mac_ok {
                println!("Réveil valide ! Relance des services...");
                for service in &config.services {
                    let status = Command::new("systemctl")
                        .args(["start", service])
                        .status()?;
                    println!("-> {} : {}", service, if status.success() { "OK" } else { "Erreur" });
                }
            }
        }
    }
}

fn print_usage() {
    println!("WOL NAS Listener - Gestion Wake-on-LAN et extinction");
    println!("");
    println!("Usage:");
    println!("  wol-nas-listener           Démarre l'écouteur WOL (mode par défaut)");
    println!("  wol-nas-listener --shutdown  Exécute la séquence d'arrêt du NAS");
    println!("  wol-nas-listener --help      Affiche cette aide");
}

fn main() -> std::io::Result<()> {
    let args: Vec<String> = env::args().collect();

    // Lecture de la configuration
    let config_data = fs::read_to_string("/etc/wol-rust/config.toml")
        .or_else(|_| fs::read_to_string("config.toml"))
        .expect("Fichier config.toml introuvable");
    let config: Config = toml::from_str(&config_data)
        .expect("Erreur de format dans config.toml");

    // Parsing des arguments
    if args.len() > 1 {
        match args[1].as_str() {
            "--shutdown" | "-s" => return run_shutdown(&config),
            "--help" | "-h" => {
                print_usage();
                return Ok(());
            }
            _ => {
                eprintln!("Option inconnue: {}", args[1]);
                print_usage();
                std::process::exit(1);
            }
        }
    }

    // Mode par défaut : écoute WOL
    run_wol_listener(&config)
}
