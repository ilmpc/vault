resource "yandex_iam_service_account" "vaultwarden_vm" { name = "vaultwarden-vm" }

# storage.uploader has no delete permission; storage.viewer permits restores/listing.
resource "yandex_resourcemanager_folder_iam_member" "storage_uploader" {
  folder_id = var.yc_folder_id
  role      = "storage.uploader"
  member    = "serviceAccount:${yandex_iam_service_account.vaultwarden_vm.id}"
}
resource "yandex_resourcemanager_folder_iam_member" "storage_viewer" {
  folder_id = var.yc_folder_id
  role      = "storage.viewer"
  member    = "serviceAccount:${yandex_iam_service_account.vaultwarden_vm.id}"
}

resource "yandex_resourcemanager_folder_iam_member" "os_login_admin" {
  count     = var.os_login_user_id == "" ? 0 : 1
  folder_id = var.yc_folder_id
  role      = "compute.osAdminLogin"
  member    = "userAccount:${var.os_login_user_id}"
}

resource "yandex_resourcemanager_folder_iam_member" "os_login_operator" {
  count     = var.os_login_user_id == "" ? 0 : 1
  folder_id = var.yc_folder_id
  role      = "compute.operator"
  member    = "userAccount:${var.os_login_user_id}"
}

resource "yandex_resourcemanager_folder_iam_member" "os_login_auditor" {
  count     = var.os_login_user_id == "" ? 0 : 1
  folder_id = var.yc_folder_id
  role      = "resource-manager.auditor"
  member    = "userAccount:${var.os_login_user_id}"
}

resource "terraform_data" "backup_bucket" {
  triggers_replace = {
    bucket         = var.backup_bucket_name
    retention_days = var.backup_retention_days
  }

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-c"]
    command     = <<-EOF
      set -eu
      bucket='${var.backup_bucket_name}'
      endpoint='vaultwarden-storage'
      if ! yc storage bucket get "$bucket" >/dev/null 2>&1; then
        yc storage bucket create "$bucket" --acl private --default-storage-class STANDARD
      fi
      if ! yc vpc private-endpoint get "$endpoint" >/dev/null 2>&1; then
        yc vpc private-endpoint create "$endpoint" \
          --network-id '${data.yandex_vpc_subnet.default.network_id}' \
          --object-storage \
          --private-dns-records-enabled \
          --address-spec subnet-id='${data.yandex_vpc_subnet.default.id}' >/dev/null
      fi
      endpoint_id="$(yc vpc private-endpoint get "$endpoint" --format json | jq -r .id)"
      yc storage bucket update "$bucket" \
        --versioning versioning-enabled \
        --lifecycle-rules '{"lifecycleRules":[{"id":"expire-backups","enabled":true,"expiration":{"days":"${var.backup_retention_days}"}}]}' \
        --enable-private-endpoints=true \
        --private-endpoints "$endpoint_id" \
        --private-endpoints-force-cloudconsole-access=true
    EOF
  }
}
