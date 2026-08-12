resource "yandex_compute_disk" "vaultwarden_data" {
  name = "vaultwarden-data"
  zone = var.yc_zone
  size = var.data_disk_size_gb
  type = "network-ssd"
}

resource "yandex_compute_instance" "vaultwarden" {
  name                      = "vaultwarden"
  zone                      = var.yc_zone
  allow_stopping_for_update = true
  service_account_id        = yandex_iam_service_account.vaultwarden_vm.id

  resources {
    cores  = var.vm_cores
    memory = var.vm_memory
  }
  boot_disk {
    initialize_params {
      image_id = var.ubuntu_image_id
      size     = 15
    }
  }
  secondary_disk {
    disk_id     = yandex_compute_disk.vaultwarden_data.id
    device_name = "vaultwarden-data"
    auto_delete = false
  }
  network_interface {
    subnet_id          = yandex_vpc_subnet.vaultwarden.id
    security_group_ids = [yandex_vpc_security_group.vaultwarden.id]
    nat                = true
    nat_ip_address     = yandex_vpc_address.vaultwarden.external_ipv4_address[0].address
  }
  metadata = {
    ssh-keys = "ubuntu:${var.vm_ssh_public_key}"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      backup_bucket_name = var.backup_bucket_name
      caddy_image        = var.caddy_image
      yc_cloud_id        = var.yc_cloud_id
      yc_folder_id       = var.yc_folder_id
      domain_name        = var.domain_name
      local_backup_keep  = var.local_backup_keep
      vaultwarden_image  = var.vaultwarden_image
      compose            = templatefile("${path.module}/templates/compose.yaml.tftpl", {})
      caddyfile          = templatefile("${path.module}/templates/Caddyfile.tftpl", { domain_name = var.domain_name })
      vaultwarden_env    = templatefile("${path.module}/templates/vaultwarden.env.tftpl", { caddy_image = var.caddy_image, domain_name = var.domain_name, vaultwarden_image = var.vaultwarden_image, admin_token = "$${admin_token}" })
      backup_script      = templatefile("${path.module}/templates/vw-backup.sh.tftpl", { backup_bucket_name = var.backup_bucket_name, local_backup_keep = var.local_backup_keep })
      restore_script     = templatefile("${path.module}/templates/vw-restore.sh.tftpl", { backup_bucket_name = var.backup_bucket_name })
      backup_service     = file("${path.module}/templates/systemd/vw-backup.service")
      backup_timer       = file("${path.module}/templates/systemd/vw-backup.timer")
    })
  }
}
