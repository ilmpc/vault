data "yandex_compute_image" "ubuntu" {
  family    = "ubuntu-2404-lts-oslogin"
  folder_id = "standard-images"
}

resource "yandex_compute_instance" "vaultwarden" {
  name                      = "vaultwarden"
  zone                      = var.yc_zone
  platform_id               = "standard-v3"
  allow_stopping_for_update = true
  service_account_id        = yandex_iam_service_account.vaultwarden_vm.id
  depends_on = [
    terraform_data.backup_bucket,
    yandex_resourcemanager_folder_iam_member.storage_uploader,
    yandex_resourcemanager_folder_iam_member.storage_viewer,
  ]

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory
    core_fraction = var.vm_core_fraction
  }
  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 15
      type     = "network-ssd"
    }
  }
  network_interface {
    subnet_id = data.yandex_vpc_subnet.default.id
    security_group_ids = [
      data.yandex_vpc_network.default.default_security_group_id,
    ]
    nat = true
  }
  metadata = {
    enable-oslogin     = "true"
    serial-port-enable = "true"
    user-data = templatefile("${path.module}/templates/cloud-init.yaml.tftpl", {
      backup_bucket_name     = var.backup_bucket_name
      caddy_image            = var.caddy_image
      docker_registry_mirror = var.docker_registry_mirror
      yc_cloud_id            = var.yc_cloud_id
      yc_folder_id           = var.yc_folder_id
      domain_name            = var.domain_name
      local_backup_keep      = var.local_backup_keep
      vaultwarden_image      = var.vaultwarden_image
      compose                = templatefile("${path.module}/templates/compose.yaml.tftpl", {})
      caddyfile              = templatefile("${path.module}/templates/Caddyfile.tftpl", { domain_name = var.domain_name })
      backup_script          = templatefile("${path.module}/templates/vw-backup.sh.tftpl", { backup_bucket_name = var.backup_bucket_name, local_backup_keep = var.local_backup_keep })
      restore_script         = templatefile("${path.module}/templates/vw-restore.sh.tftpl", { backup_bucket_name = var.backup_bucket_name })
      backup_service         = file("${path.module}/templates/systemd/vw-backup.service")
      backup_timer           = file("${path.module}/templates/systemd/vw-backup.timer")
      compose_service        = file("${path.module}/templates/systemd/vaultwarden-compose.service")
    })
  }
}
