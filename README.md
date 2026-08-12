# Vaultwarden on Yandex Cloud

Minimal OpenTofu skeleton: one VM, separate data disk, Caddy TLS, private versioned Object Storage backups, and a Cloudflare DNS record. `ADMIN_TOKEN` is generated only on the VM at first boot and is never passed to OpenTofu.

Copy `.env.example` to `.env` for local credentials, then create `infra/terraform.tfvars` from `infra/terraform.tfvars.example`:

```hcl
yc_cloud_id = "..."
yc_folder_id = "..."
domain_name = "vault.example.com"
cloudflare_zone_id = "..."
vm_ssh_public_key = "ssh-ed25519 ..."
ssh_allowed_cidrs = ["203.0.113.10/32"]
ubuntu_image_id = "..."
backup_bucket_name = "globally-unique-name"
```

Do not put `cloudflare_api_token` into `terraform.tfvars`; `.env` exports it as `TF_VAR_cloudflare_api_token`.

```bash
set -a
source .env
set +a
cd infra
tofu fmt -recursive
tofu init
tofu validate
tofu plan
```

This setup does not run `tofu apply`. After a future apply, use the `ssh_tunnel_command` output and open `http://127.0.0.1:8080/admin` locally.

On the VM: `sudo vw-backup`, `sudo vw-restore list`, `sudo vw-restore latest`, or `sudo vw-restore TIMESTAMP`.

GitHub:

```bash
set -a
source .env
set +a
gh auth status -h github.com
```
