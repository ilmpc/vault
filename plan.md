# План деплоя Vaultwarden в Yandex Cloud

Дата: 2026-08-11

Цель: воспроизводимый деплой Vaultwarden на одной VM в Yandex Cloud, с локальным persistent disk, SQLite, публичным HTTPS через Caddy, закрытой админкой через SSH port forward, простыми бэкапами в Yandex Object Storage и понятным скриптом отката.

## 1. Базовое решение

Используем самый скучный вариант:

- одна Compute VM;
- один отдельный persistent disk под `/srv/vaultwarden`;
- Docker Compose;
- закрепленная версия или digest `vaultwarden/server`;
- SQLite по умолчанию в `/data/db.sqlite3`;
- закрепленная версия `caddy` как reverse proxy;
- Object Storage только для бэкапов, не как live storage;
- Cloudflare DNS A-record на публичный IP VM;
- `/admin` не публикуем наружу, доступ только через SSH tunnel.

Не используем PostgreSQL на той же VM. Он не решает проблему потерянного состояния, зато добавляет отдельный сервис, дампы, миграции и больше мест для ошибки.

## 2. Ответы на спорные места

### Можно ли сразу класть скрипты через IaC?

Да. Terraform/OpenTofu создает ресурсы, а `cloud-init` через VM metadata кладет на машину:

- `compose.yaml`;
- `Caddyfile`;
- backup script;
- backup systemd service/timer;
- bootstrap script для установки Docker, Compose plugin, `yc` CLI и `sqlite3`.

Логика: Terraform отвечает за инфраструктуру, `cloud-init` отвечает за настройку VM. Не используем `remote-exec`, чтобы деплой не зависел от SSH-сессии с локальной машины.

### Нужны ли шифрованные бэкапы?

Пока нет. Это личный Vaultwarden, bucket приватный, а главная цель - не потерять состояние и легко откатиться. Убираем `age`, private key, restore-test VM и canary-user.

Что остается:

- private Object Storage bucket;
- bucket versioning;
- VM service account без `DeleteObject`;
- полный tar.gz всего `vw-data`;
- checksum рядом с архивом;
- manifest `manifests/latest.json`;
- простой скрипт `vw-restore`, который умеет откатиться на последний backup или на конкретную дату.

Если позже bucket начнет шариться между людьми, появятся compliance-требования или там будут лежать не только vaultwarden-бэкапы, добавить `age` обратно несложно.

## 3. IaC структура

Предлагаемый layout:

```text
infra/
  versions.tf
  providers.tf
  variables.tf
  outputs.tf
  network.tf
  security.tf
  object-storage.tf
  compute.tf
  cloudflare.tf
  templates/
    cloud-init.yaml.tftpl
    compose.yaml.tftpl
    Caddyfile.tftpl
    vaultwarden.env.tftpl
    vw-backup.sh.tftpl
    vw-restore.sh.tftpl
    systemd/
      vw-backup.service
      vw-backup.timer
```

Минимальные Terraform variables:

```hcl
yc_cloud_id
yc_folder_id
yc_zone
domain_name
cloudflare_zone_id
vm_ssh_public_key
vaultwarden_image
caddy_image
backup_bucket_name
backup_retention_days = 30 # можно увеличить, объем будет маленький
local_backup_keep = 3
```

Секреты не коммитим и не кладем в Terraform/cloud-init metadata:

- `YC_TOKEN` или service account key для Terraform;
- `CLOUDFLARE_API_TOKEN`;
- Vaultwarden `ADMIN_TOKEN`.

`ADMIN_TOKEN` создается на VM при первом bootstrap или задается вручную через SSH после деплоя. Object Storage credentials не нужны: VM работает через привязанный service account и `yc storage s3 cp`.

В Terraform variables/templates не передаем `ADMIN_TOKEN`. В cloud-init можно передавать только несекретные значения: домен, bucket name, image versions, cloud/folder ids.

## 4. Yandex Cloud ресурсы

Terraform/OpenTofu создает:

- VPC network;
- subnet;
- security group;
- static public IP;
- Compute VM;
- отдельный data disk;
- Object Storage bucket для бэкапов;
- versioning на bucket;
- lifecycle policy на bucket;
- service account для production VM;
- bucket IAM/policy для production VM service account.

Terraform state:

- хранить только в зашифрованном и ограниченном backend;
- не коммитить local `terraform.tfstate`;
- проверить `tofu show`/`terraform show` перед первым реальным использованием;
- если secret value попал в state, считать его скомпрометированным и перевыпустить.

IAM matrix:

- production VM service account:
  - `PutObject`, `GetObject`, `ListBucket` только для backup prefix;
  - без `DeleteObject`;
  - имена объектов всегда уникальные timestamp-based, overwrite не используется.
- Terraform service account:
  - управляет ресурсами и IAM;
  - не содержит payload секретов в state.

Security group:

- `22/tcp` только с доверенных IP;
- `80/tcp` public для ACME HTTP-01;
- `443/tcp` public;
- Vaultwarden internal port не открыт наружу.

## 5. Cloudflare DNS

Terraform Cloudflare provider создает:

- `A vault.example.com -> static public IP`;
- `proxied = false` по умолчанию.

Почему `proxied=false`: меньше TLS/ACME сюрпризов. Caddy сам получает и обновляет Let's Encrypt certificate.

Cloudflare proxy можно включить позже, когда базовый restore path уже проверен.

## 6. VM bootstrap

`cloud-init` делает:

1. Устанавливает Docker и Docker Compose plugin.
2. Ставит `yc` CLI и `sqlite3`.
3. Монтирует data disk в `/srv/vaultwarden`.
4. Создает директории:
   - `/srv/vaultwarden/vw-data`;
   - `/srv/vaultwarden/caddy-data`;
   - `/srv/vaultwarden/caddy-config`;
   - `/opt/vaultwarden`;
   - `/var/lib/vaultwarden-backups`.
5. Настраивает `yc` CLI profile для attached service account через metadata.
6. Пишет:
   - `/opt/vaultwarden/compose.yaml`;
   - `/opt/vaultwarden/Caddyfile`;
   - `/opt/vaultwarden/.env`;
   - `/usr/local/sbin/vw-backup`;
   - `/usr/local/sbin/vw-restore`.
7. Включает systemd timers.
8. Запускает `docker compose up -d`.

Важно:

- disk formatting должен быть idempotent: форматировать только если на диске нет filesystem;
- mount делать по UUID через `/etc/fstab`;
- не использовать `nofail` для data disk;
- перед стартом Vaultwarden и backup проверять `mountpoint -q /srv/vaultwarden`, иначе fail fast, чтобы данные не уехали на root disk;
- `cloud-init` работает только на первом старте VM. Для изменения bootstrap-шаблонов либо пересоздаем VM с сохранением data disk, либо запускаем отдельную идемпотентную apply-команду. Не рассчитываем, что изменение Terraform template само обновит уже живую VM.

## 7. Docker Compose

Production compose:

```yaml
services:
  vaultwarden:
    image: ${VAULTWARDEN_IMAGE}
    container_name: vaultwarden
    restart: unless-stopped
    env_file: .env
    volumes:
      - /srv/vaultwarden/vw-data:/data
    ports:
      - "127.0.0.1:8080:80"

  caddy:
    image: ${CADDY_IMAGE}
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - /opt/vaultwarden/Caddyfile:/etc/caddy/Caddyfile:ro
      - /srv/vaultwarden/caddy-data:/data
      - /srv/vaultwarden/caddy-config:/config
```

Vaultwarden `.env`:

```env
VAULTWARDEN_IMAGE=vaultwarden/server:<version-or-digest>
CADDY_IMAGE=caddy:<version-or-digest>
DOMAIN=https://vault.example.com
SIGNUPS_ALLOWED=false
ADMIN_TOKEN=<generated-on-vm>
```

`ADMIN_TOKEN` создается локально на VM и хранится только в `/opt/vaultwarden/.env`.

Первый пользователь:

- зайти в admin через SSH tunnel;
- создать/invite owner account;
- signups остаются disabled.

SSH tunnel:

```bash
ssh -N -L 8080:127.0.0.1:8080 yc-user@<vm-ip>
```

Потом открыть:

```text
http://127.0.0.1:8080/admin
```

SSH на VM:

- password login disabled;
- remote forwarding disabled;
- доступ на `22/tcp` только с доверенных IP.

Forward открывает локально весь Vaultwarden, а не только `/admin`. Это нормально для администрирования, но публичный Caddy все равно закрывает `/admin`.

## 8. Caddy

`Caddyfile`:

```caddyfile
vault.example.com {
  encode zstd gzip

  @admin path /admin /admin/*
  respond @admin 404

  reverse_proxy vaultwarden:80
}
```

Так публичный `/admin` не доступен. Через SSH tunnel идем напрямую в Vaultwarden на `127.0.0.1:8080`.

## 9. Backup job

Backup должен архивировать весь `vw-data`, а не только `db.sqlite3`.

Причина: DB backup не включает attachments, config, RSA keys, sends.

Алгоритм `/usr/local/sbin/vw-backup`:

1. Взять `flock`, чтобы backup jobs не пересекались.
2. `set -Eeuo pipefail`.
3. Проверить `mountpoint -q /srv/vaultwarden`.
4. Поставить `trap`, который всегда стартует Vaultwarden обратно и удаляет plaintext/temp files.
5. `cd /opt/vaultwarden`.
6. `docker compose stop vaultwarden`.
7. Создать tar.gz всего `/srv/vaultwarden/vw-data` во временный каталог.
8. `docker compose start vaultwarden`.
9. Посчитать sha256 архива.
10. Проверить checksum локально.
11. Загрузить `.tar.gz` и `.sha256` в Object Storage под уникальным timestamp.
12. Последним загрузить маленький manifest `manifests/latest.json` со ссылками на archive/checksum.
13. Удалить локальные временные файлы.
14. Оставить последние 2-3 локальных backup как emergency cache.

Расписание:

- daily backup ночью;
- backup перед обновлением контейнера;
- lifecycle в bucket: 30 дней по умолчанию, можно поставить 90/180/365, объем должен быть маленький.

Object Storage upload:

```bash
yc storage s3 cp "$archive" "s3://$BUCKET/vaultwarden/backups/$timestamp/$name"
```

VM не должна иметь прав delete на backup objects. Retention чистится lifecycle policy, не скриптом. Bucket versioning включен, чтобы случайный overwrite не был мгновенной потерей.

## 10. Restore / rollback script

Вместо отдельной restore-test VM оставляем понятный аварийный скрипт `/usr/local/sbin/vw-restore`.

Команды:

```bash
sudo vw-restore list
sudo vw-restore latest
sudo vw-restore 2026-08-12T03-00-00
```

Что делает `vw-restore latest`:

1. Проверяет `mountpoint -q /srv/vaultwarden`.
2. Читает `manifests/latest.json`.
3. Скачивает archive и checksum в `/var/lib/vaultwarden-restore`.
4. Проверяет sha256.
5. Делает локальный safety backup текущего `/srv/vaultwarden/vw-data`.
6. Останавливает Vaultwarden.
7. Переименовывает текущий `vw-data` в `vw-data.before-restore-<timestamp>`.
8. Распаковывает backup как новый `/srv/vaultwarden/vw-data`.
9. Запускает Vaultwarden.
10. Показывает последние логи контейнера.

Что делает `vw-restore <timestamp>`:

- берет backup из `s3://$BUCKET/vaultwarden/backups/<timestamp>/`;
- дальше делает тот же flow.

Важно:

- restore script ничего не удаляет сразу;
- старый `vw-data.before-restore-*` остается на диске до ручной чистки;
- перед restore на всякий случай создается локальный safety backup текущего состояния;
- если restore не стартанул, можно вернуть предыдущую директорию руками.

## 11. Update procedure

Перед обновлением:

```bash
sudo /usr/local/sbin/vw-backup
```

Потом:

```bash
cd /opt/vaultwarden
sed -i 's#VAULTWARDEN_IMAGE=.*#VAULTWARDEN_IMAGE=vaultwarden/server:<new-version-or-digest>#' .env
docker compose pull
docker compose up -d
docker logs --tail=100 vaultwarden
```

После обновления:

- зайти web/mobile client;
- проверить login;
- сохранить предыдущий image digest для rollback.

## 12. Disaster recovery

На новую VM:

1. Развернуть IaC.
2. Скачать нужный backup из Object Storage или использовать `/usr/local/sbin/vw-restore latest`, если manifest уже доступен на VM.
3. Если восстанавливаем руками, остановить Vaultwarden:

```bash
cd /opt/vaultwarden
docker compose stop vaultwarden
```

4. Проверить checksum:

```bash
sha256sum -c backup.tar.gz.sha256
```

5. Распаковать в `/srv/vaultwarden/vw-data`.
6. Стартануть:

```bash
docker compose up -d
```

7. Проверить:
   - login owner account;
   - attachments;
   - organizations.

## 13. Что сделать сначала

1. Создать IaC skeleton.
2. Добавить VM + disk + network + security group.
3. Добавить Object Storage bucket + lifecycle.
4. Добавить cloud-init templates.
5. Поднять Vaultwarden + Caddy.
6. Настроить Cloudflare DNS.
7. Создать owner account через SSH tunnel.
8. Создать первый backup.
9. Один раз руками прогнать `sudo vw-restore list` и проверить, что бэкап виден.
10. Только после первого успешного backup начать пользоваться как основным password manager.

## 14. GitHub и проверка реализации

Код живет прямо в `~/ass/vault`.

В git кладем:

- `infra/*.tf`;
- `infra/templates/*`;
- `scripts/*`, если будут локальные helper-скрипты;
- `.env.example`;
- `.gitignore`;
- `README.md`;
- этот `plan.md`.

В git не кладем:

- `.env`;
- `.terraform/`;
- `terraform.tfstate*`;
- crash/log files;
- реальные backup archives;
- локальные generated files с `ADMIN_TOKEN`.

Локальная `.env` нужна только для запуска с машины владельца:

```env
CLOUDFLARE_API_TOKEN=...
GH_TOKEN=...
```

GitHub auth:

- `gh` credential store может быть протухшим, но `GH_TOKEN` можно хранить в локальном `.env`;
- локальную реализацию можно писать и тестировать без GitHub;
- create remote / push делаем через `GH_TOKEN` или после `gh auth login -h github.com`.

Минимальные проверки перед apply:

```bash
cd ~/ass/vault/infra
tofu fmt -recursive
tofu init
tofu validate
source ../.env
tofu plan
```

Тест реализации без запуска production:

1. `tofu validate` должен проходить.
2. `tofu plan` должен показать создание VM, disk, bucket, service account, IAM, security group и Cloudflare DNS.
3. В plan не должно быть `ADMIN_TOKEN`, Cloudflare token, YC token или других секретов.
4. Template rendering не должен класть секреты в cloud-init metadata.
5. Backup/restore scripts должны проходить `bash -n`.

Smoke после реального apply:

1. VM поднялась.
2. `https://<domain>` открывается.
3. `/admin` через публичный HTTPS отдает 404.
4. `/admin` доступен через SSH tunnel.
5. `sudo vw-backup` создает объект в bucket.
6. `sudo vw-restore list` видит backup.

## 15. Что сознательно не делаем сейчас

- Не делаем Dockerized PostgreSQL.
- Не делаем S3 live storage.
- Не делаем Kubernetes/Container Runtime.
- Не делаем HA: SQLite и один password manager на одной VM не становятся HA от второй копии.
- Не шифруем backup поверх клиентского Bitwarden/Vaultwarden encryption.
- Не делаем отдельную restore-test VM.
- Не делаем canary-user.

Добавить это стоит только когда появится конкретная боль, а не заранее.
