use std::fs;
use std::net::UdpSocket;
use std::process::Command;
use serde::Deserialize;

#[derive(Deserialize)]
struct Config {
    interface: String,
    port: u16,
    services: Vec<String>,
}

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

fn main() -> std::io::Result<()> {
    // Lecture de la configuration
    let config_data = fs::read_to_string("config.toml").expect("Fichier config.toml introuvable");
    let config: Config = toml::from_str(&config_data).expect("Erreur de format dans config.toml");

    // Détection auto de l'adresse MAC
    let my_mac = get_mac_address(&config.interface).expect("Impossible de lire l'adresse MAC");

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
                    let status = Command::new("systemctl").arg("start").arg(service).status()?;
                    println!("-> {} : {}", service, if status.success() { "OK" } else { "Erreur" });
                }
            }
        }
    }
}
