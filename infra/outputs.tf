output "public_ip" { value = yandex_vpc_address.vaultwarden.external_ipv4_address[0].address }
output "ssh_tunnel_command" { value = "ssh -N -L 8080:127.0.0.1:8080 ubuntu@${yandex_vpc_address.vaultwarden.external_ipv4_address[0].address}" }
