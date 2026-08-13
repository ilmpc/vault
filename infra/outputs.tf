output "public_ip" { value = yandex_compute_instance.vaultwarden.network_interface[0].nat_ip_address }
output "ssh_tunnel_command" { value = "yc compute ssh --name vaultwarden --folder-id ${var.yc_folder_id} -- -N -L 8080:127.0.0.1:8080" }
