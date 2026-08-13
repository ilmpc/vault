# Vaultwarden on Yandex Cloud

Minimal OpenTofu skeleton: one VM, separate data disk, Caddy TLS, private Object Storage backups, and a Cloudflare DNS record. `ADMIN_TOKEN` is generated only on the VM at first boot and is never passed to OpenTofu.

Copy `.env.example` to `.env` for local credentials, then create `infra/terraform.tfvars` from `infra/terraform.tfvars.example`:

```hcl
yc_cloud_id = "..."
yc_folder_id = "..."
domain_name = "vault.example.com"
cloudflare_zone_id = "..."
os_login_user_id = "aje..."
backup_bucket_name = "globally-unique-name"
```

Do not put `cloudflare_api_token` into `terraform.tfvars`; `.env` exports it as `TF_VAR_cloudflare_api_token`.

```bash
set -a
source .env
set +a
export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"
cd infra
tofu fmt -recursive
tofu init
tofu validate
tofu plan
```

This setup uses Yandex Cloud OS Login, not SSH keys in VM metadata. After apply, use the `ssh_tunnel_command` output and open `http://127.0.0.1:8080/admin` locally.
Use an OS Login image, e.g. the latest `ubuntu-2404-lts-oslogin` image.

On the VM: `sudo vw-backup`, `sudo vw-restore list`, `sudo vw-restore latest`, or `sudo vw-restore TIMESTAMP`.

`tofu destroy` removes compute and DNS but intentionally retains the backup bucket, so backups cannot disappear by accident. A fresh `tofu apply` restores from the latest backup only if the bucket still contains one.

GitHub:

```bash
set -a
source .env
set +a
gh auth status -h github.com
```
