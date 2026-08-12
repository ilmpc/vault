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
resource "yandex_storage_bucket" "backups" {
  bucket = var.backup_bucket_name
  acl    = "private"
  versioning { enabled = true }
  lifecycle_rule {
    id      = "expire-backups"
    enabled = true
    expiration { days = var.backup_retention_days }
  }
}
