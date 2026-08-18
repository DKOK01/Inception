# Inception — Full Implementation Plan

> **Workflow:** Code on the **Host** (school PC) → Sync to the **VM** via `scp` → Build & run Docker containers inside the **VM** via SSH.

---

## Phase 0: Environment Preparation (VM Side)

> Goal: Prepare the VM so it's ready to receive code and run Docker containers.

### Task 0.1 — Install Docker (via `apt`, NOT snap)
Run inside the VM (via SSH `ssh aysadeq@localhost -p 2222`):
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose make openssl
sudo usermod -aG docker $USER
newgrp docker
docker ps   # Verify: should show empty table, no permission error
```

### Task 0.2 — Create persistent data directories
The subject requires named volumes to store data at `/home/login/data/` on the host machine (the VM in our case):
```bash
sudo mkdir -p /home/aysadeq/data/mariadb
sudo mkdir -p /home/aysadeq/data/wordpress
sudo chown -R aysadeq:aysadeq /home/aysadeq/data
```

### Task 0.3 — Configure domain name inside the VM
The subject requires `aysadeq.42.fr` to resolve to the local IP:
```bash
echo "127.0.0.1 aysadeq.42.fr" | sudo tee -a /etc/hosts
```

---

## Phase 1: Project Structure & Sync Script (Host Side)

> Goal: Create the full directory tree on the host and a one-command sync mechanism.

### Task 1.1 — Create directory structure
On the **host**, create the project skeleton exactly as the subject specifies:

```
/home/aysadeq/Desktop/Inception/
├── Makefile
├── secrets/
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
├── srcs/
│   ├── .env
│   ├── docker-compose.yml
│   └── requirements/
│       ├── mariadb/
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/
│       │   │   └── 50-server.cnf
│       │   └── tools/
│       │       └── init-db.sh
│       ├── nginx/
│       │   ├── Dockerfile
│       │   ├── .dockerignore
│       │   ├── conf/
│       │   │   └── nginx.conf
│       │   └── tools/
│       │       └── setup-ssl.sh
│       └── wordpress/
│           ├── Dockerfile
│           ├── .dockerignore
│           ├── conf/
│           │   └── www.conf
│           └── tools/
│               └── setup-wp.sh
```

### Task 1.2 — Create the sync script
We'll use `rsync` over SSH — it's faster than `scp` because it only transfers **changed files**, not everything every time.

**File: `sync.sh`** (at the project root on the host)
```bash
#!/bin/bash
rsync -avz --exclude='.git' -e 'ssh -p 2222' \
  /home/aysadeq/Desktop/Inception/ \
  aysadeq@localhost:~/Inception/
```
Make it executable: `chmod +x sync.sh`

**Usage:** After any code change, run `./sync.sh` from the host, then switch to your SSH terminal and run `make` inside the VM.

### Task 1.3 — Create `.gitignore`
```gitignore
secrets/
srcs/.env
*.iso
```

> [!CAUTION]
> The subject states: *"Any credentials, API keys, or passwords found in your Git repository will result in project failure."* Never commit `secrets/` or `.env`.

---

## Phase 2: Environment Variables & Secrets

> Goal: Set up all configuration values before writing any Docker code.

### Task 2.1 — Create `srcs/.env`
This file is read by Docker Compose and injected into containers:
```env
# Domain
DOMAIN_NAME=aysadeq.42.fr

# MariaDB
MYSQL_DATABASE=wordpress_db
MYSQL_USER=wp_user

# WordPress admin (username must NOT contain admin/Admin/administrator)
WP_ADMIN_USER=superchief
WP_ADMIN_EMAIL=superchief@42.fr

# WordPress regular user
WP_USER=editor42
WP_USER_EMAIL=editor@42.fr
```

> [!IMPORTANT]
> No passwords in `.env` — those go into Docker Secrets (see Task 2.2).

### Task 2.2 — Create Docker Secrets files
```
secrets/db_password.txt       → The password for the MySQL wp_user
secrets/db_root_password.txt  → The MySQL root password
secrets/credentials.txt       → WordPress admin & user passwords (line 1 = admin pw, line 2 = user pw)
```

These files will be mounted into containers at `/run/secrets/<secret_name>` via Docker Compose. Your entrypoint scripts will read passwords from these files instead of from environment variables.

---

## Phase 3: MariaDB Container

> Goal: Build a container that initializes the database, creates the WordPress user, and runs `mysqld` in the foreground as PID 1.

### Task 3.1 — Write `srcs/requirements/mariadb/Dockerfile`
- `FROM debian:bookworm` (penultimate stable — **not** `latest`, **not** `trixie`)
- `RUN apt-get update && apt-get install -y mariadb-server && rm -rf /var/lib/apt/lists/*` (single layer, clean up apt cache)
- `COPY conf/50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf`
- `COPY tools/init-db.sh /usr/local/bin/init-db.sh`
- `RUN chmod +x /usr/local/bin/init-db.sh`
- `EXPOSE 3306`
- `ENTRYPOINT ["init-db.sh"]` (Exec form — critical for PID 1 signal handling)

> [!WARNING]
> No passwords in the Dockerfile. No `CMD tail -f`. No `sleep infinity`.

### Task 3.2 — Write `conf/50-server.cnf`
Key change: set `bind-address = 0.0.0.0` so MariaDB listens on all interfaces (not just localhost), allowing the WordPress container to connect over the Docker network.

### Task 3.3 — Write `tools/init-db.sh`
This entrypoint script must:
1. Read passwords from Docker Secrets (`/run/secrets/db_password`, `/run/secrets/db_root_password`).
2. Start MariaDB temporarily in safe mode to run initialization SQL:
   - Create the WordPress database.
   - Create the `wp_user` with the secret password and grant privileges.
   - Set the root password.
   - Flush privileges.
3. Stop the temporary MariaDB.
4. **`exec mysqld`** — Replace the shell process with `mysqld` so it becomes PID 1 (proper signal handling, no zombie reaping issues).

> [!IMPORTANT]
> Use `exec` to replace the bash process with `mysqld`. This ensures `mysqld` becomes PID 1 and receives `SIGTERM` directly from `docker stop`.

---

## Phase 4: WordPress + PHP-FPM Container

> Goal: Build a container that downloads WordPress, configures it to connect to MariaDB, creates the required users, and runs `php-fpm` in the foreground.

### Task 4.1 — Write `srcs/requirements/wordpress/Dockerfile`
- `FROM debian:bookworm`
- Install: `php-fpm`, `php-mysql`, `php-curl`, `php-gd`, `php-xml`, `php-mbstring`, `curl`, `mariadb-client`
- Download WP-CLI: `curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar` → move to `/usr/local/bin/wp`
- `COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf`
- `COPY tools/setup-wp.sh /usr/local/bin/setup-wp.sh`
- `EXPOSE 9000`
- `ENTRYPOINT ["setup-wp.sh"]`

### Task 4.2 — Write `conf/www.conf`
Key change: set `listen = 9000` (TCP socket instead of Unix socket), so NGINX can reach PHP-FPM over the Docker network.

### Task 4.3 — Write `tools/setup-wp.sh`
This entrypoint script must:
1. Read passwords from Docker Secrets.
2. **Wait for MariaDB** to be ready using a loop:
   ```bash
   while ! mariadb -h mariadb -u "$MYSQL_USER" -p"$DB_PASSWORD" "$MYSQL_DATABASE" -e "SELECT 1;" &>/dev/null; do
       echo "Waiting for MariaDB..."
       sleep 2
   done
   ```
3. Download WordPress core files via WP-CLI (if not already present).
4. Generate `wp-config.php` via WP-CLI using environment variables and secrets.
5. Run `wp core install` with the admin user (whose name does **not** contain "admin").
6. Create the second regular user via `wp user create`.
7. Create the `/run/php/` directory for php-fpm.
8. **`exec php-fpm8.2 -F`** — The `-F` flag keeps php-fpm in the foreground as PID 1.

> [!IMPORTANT]
> WP-CLI commands must be run with `--allow-root` if the container runs as root.

---

## Phase 5: NGINX Container

> Goal: Build a container that serves as the single HTTPS entrypoint, generates a self-signed TLS certificate, and proxies PHP requests to WordPress.

### Task 5.1 — Write `srcs/requirements/nginx/Dockerfile`
- `FROM debian:bookworm`
- `RUN apt-get update && apt-get install -y nginx openssl && rm -rf /var/lib/apt/lists/*`
- `COPY conf/nginx.conf /etc/nginx/nginx.conf`
- `COPY tools/setup-ssl.sh /usr/local/bin/setup-ssl.sh`
- `EXPOSE 443`
- `ENTRYPOINT ["setup-ssl.sh"]`

### Task 5.2 — Write `tools/setup-ssl.sh`
1. Generate a self-signed SSL certificate using OpenSSL:
   ```bash
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
       -keyout /etc/ssl/private/nginx.key \
       -out /etc/ssl/certs/nginx.crt \
       -subj "/C=MA/ST=State/L=City/O=42/CN=aysadeq.42.fr"
   ```
2. **`exec nginx -g "daemon off;"`** — Run NGINX in the foreground as PID 1.

### Task 5.3 — Write `conf/nginx.conf`
Key directives:
```nginx
server {
    listen 443 ssl;
    server_name aysadeq.42.fr;

    ssl_certificate     /etc/ssl/certs/nginx.crt;
    ssl_certificate_key /etc/ssl/private/nginx.key;
    ssl_protocols       TLSv1.2 TLSv1.3;    # Subject requirement

    root /var/www/wordpress;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    location ~ \.php$ {
        fastcgi_pass wordpress:9000;         # Connects to WordPress container
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }
}
```

> [!IMPORTANT]
> NGINX must be the **only** entrypoint into the infrastructure. Only port `443` is exposed. No port `80`.

---

## Phase 6: Docker Compose & Makefile

> Goal: Wire everything together with the compose file and provide convenient Makefile targets.

### Task 6.1 — Write `srcs/docker-compose.yml`

```yaml
version: '3.8'

services:
  mariadb:
    build: ./requirements/mariadb
    container_name: mariadb
    restart: always
    env_file: .env
    secrets:
      - db_password
      - db_root_password
    volumes:
      - mariadb_vol:/var/lib/mysql
    networks:
      - inception

  wordpress:
    build: ./requirements/wordpress
    container_name: wordpress
    restart: always
    depends_on:
      - mariadb
    env_file: .env
    secrets:
      - db_password
      - credentials
    volumes:
      - wordpress_vol:/var/www/wordpress
    networks:
      - inception

  nginx:
    build: ./requirements/nginx
    container_name: nginx
    restart: always
    depends_on:
      - wordpress
    ports:
      - "443:443"
    volumes:
      - wordpress_vol:/var/www/wordpress
    networks:
      - inception

secrets:
  db_password:
    file: ../../secrets/db_password.txt
  db_root_password:
    file: ../../secrets/db_root_password.txt
  credentials:
    file: ../../secrets/credentials.txt

volumes:
  mariadb_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/aysadeq/data/mariadb
  wordpress_vol:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/aysadeq/data/wordpress

networks:
  inception:
    driver: bridge
```

**Subject compliance notes:**
- ✅ `restart: always` — containers restart on crash
- ✅ Named volumes with `driver_opts` to store at `/home/aysadeq/data/`
- ✅ Custom bridge network `inception` (no `host`, no `--link`)
- ✅ Only NGINX exposes a port (`443`)
- ✅ Secrets mounted from files (not env vars for passwords)
- ✅ No `latest` tag — images built from our own Dockerfiles

### Task 6.2 — Write the root `Makefile`

```makefile
all:
	@mkdir -p /home/aysadeq/data/mariadb /home/aysadeq/data/wordpress
	docker-compose -f srcs/docker-compose.yml up -d --build

down:
	docker-compose -f srcs/docker-compose.yml down

clean: down
	docker-compose -f srcs/docker-compose.yml down -v --rmi all

fclean: clean
	sudo rm -rf /home/aysadeq/data/mariadb/*
	sudo rm -rf /home/aysadeq/data/wordpress/*

re: fclean all

.PHONY: all down clean fclean re
```

---

## Phase 7: Testing & Validation

> Goal: Verify every subject requirement before submission.

### Task 7.1 — Build and start
```bash
# On the host:
./sync.sh

# In the VM (SSH):
cd ~/Inception
make
```

### Task 7.2 — Verification checklist

| # | Check | Command / Method |
|---|-------|-----------------|
| 1 | All 3 containers running | `docker ps` — should show `mariadb`, `wordpress`, `nginx` |
| 2 | HTTPS works | Inside VM: `curl -k https://aysadeq.42.fr` |
| 3 | TLS version correct | `curl -k -v https://aysadeq.42.fr 2>&1 \| grep TLS` — must show TLSv1.2 or TLSv1.3 |
| 4 | No port 80 | `docker ps` — only port 443 mapped |
| 5 | WordPress loads | Browser on host: `https://localhost:8443` (accept self-signed cert warning) |
| 6 | Admin user works | Log into WordPress admin panel — admin username must **not** contain "admin" |
| 7 | Second user exists | Check WordPress Users page in admin panel |
| 8 | Data persists | Run `make down && make` — WordPress should still have your data |
| 9 | Containers restart on crash | `docker kill mariadb` — wait 5 sec — `docker ps` — mariadb should be back |
| 10 | No `latest` tag | `docker images` — no image tagged `latest` |
| 11 | No passwords in Dockerfiles | `grep -r "password" srcs/requirements/*/Dockerfile` — should return nothing |
| 12 | Secrets used | `docker exec wordpress cat /run/secrets/db_password` — should show the password |
| 13 | Volumes at correct path | `ls /home/aysadeq/data/mariadb/` and `ls /home/aysadeq/data/wordpress/` — should have data |

### Task 7.3 — Documentation
Create the following files at the project root:
- **`README.md`** — Project description, VM vs Docker comparison, Secrets vs Env Vars, Network vs Host, Volumes vs Bind Mounts
- **`USER_DOC.md`** — How to start/stop, access the site, manage credentials
- **`DEV_DOC.md`** — Environment setup from scratch, build commands, data locations

---

## Phase 8 (Bonus): Additional Services

> Only attempt after Phase 7 passes perfectly.

| Bonus | Container | Notes |
|-------|-----------|-------|
| **Redis Cache** | `redis` | Add as WordPress object cache; install `redis-server`, configure `wp-config.php` to use Redis |
| **FTP Server** | `vsftpd` | Point to the WordPress volume; configure passive mode ports |
| **Static Website** | Your choice (e.g., Node.js, Python) | Must NOT be PHP; a simple portfolio/resume site |
| **Adminer** | `adminer` | Lightweight DB management UI; connect to MariaDB |
| **Your Choice** | e.g., Portainer, Grafana, Cadvisor | Be ready to justify your choice during defense |

Each bonus service needs its own Dockerfile, its own container, and optionally its own volume. Add them as new services in `docker-compose.yml`. You may open additional ports for bonus services.

---

## Quick Reference: Subject Rules Compliance

| Rule | How We Comply |
|------|---------------|
| Penultimate stable Debian/Alpine | `FROM debian:bookworm` (Debian 12, since Debian 13 is current) |
| No `latest` tag | Pinned to `bookworm` explicitly |
| No passwords in Dockerfiles | All passwords in `/secrets/*.txt`, mounted via Docker Secrets |
| No `tail -f`, `sleep infinity`, `while true` | All services run in foreground via `exec` + daemon-off flags |
| PID 1 best practices | Exec form for ENTRYPOINT; `exec` in scripts replaces shell with app |
| `restart: always` | Set on every service in docker-compose |
| Named volumes (no bind mounts) | Using `driver_opts` with `type: none` to map to `/home/aysadeq/data/` |
| Custom bridge network | `inception` network with `driver: bridge` |
| Only port 443 exposed via NGINX | Only NGINX has a `ports:` mapping |
| TLSv1.2 or TLSv1.3 only | `ssl_protocols TLSv1.2 TLSv1.3;` in nginx.conf |
| Admin username not containing "admin" | Using `superchief` as admin username |
| Two WordPress users | Admin + regular editor created via WP-CLI |
| `.env` for non-secret config | Domain, usernames, DB name in `.env` |
| Secrets for credentials | Passwords in `secrets/*.txt`, read at runtime |
| `network: host` and `--link` forbidden | Using custom bridge network only |
