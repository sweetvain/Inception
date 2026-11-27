# Developer documentation

This document explains how to set up, build, run and maintain the Inception stack from scratch. For daily usage, see `USER_DOC.md`.

## 1. Set up the environment from scratch

### Prerequisites

The project must run in a Debian virtual machine (Debian 12 "Bookworm" was used) with:

- Docker Engine and the Docker Compose plugin
- `make`, `git`, `openssl`

Install Docker from the official repository:

```
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg make git openssl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

Log out and in again so the `docker` group applies, then check with `docker --version` and `docker compose version`.

### Domain name

The website is served on `elal-hai.42.fr`. Point it to the local machine:

```
echo "127.0.0.1 elal-hai.42.fr" | sudo tee -a /etc/hosts
```

### Get the sources

```
git clone git@github.com:sweetvain/Inception.git
cd Inception
```

### Configuration files

Two kinds of files are ignored by git (see `.gitignore`) and must be created locally.

**Secrets**, in `secrets/`:

| File | Content |
|---|---|
| `db_root_password.txt` | The MariaDB root password, on one line |
| `db_password.txt` | The password of the WordPress database user, on one line |
| `credentials.txt` | Two lines: `WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...` |

Generate strong passwords with `openssl rand -base64 24`, and restrict the access with `chmod 600 secrets/*.txt`. Everything after the `=` is the password, so do not add spaces, quotes or `<` `>`.

**Environment file**, `srcs/.env`, with the non-sensitive variables:

| Variable | Meaning |
|---|---|
| `DOMAIN_NAME` | Domain name of the site (`elal-hai.42.fr`) |
| `MYSQL_DATABASE` | Name of the WordPress database |
| `MYSQL_USER` | Database user used by WordPress |
| `WP_TITLE` | Title of the website |
| `WP_ADMIN_USER` | Administrator login (must not contain `admin` or `administrator`) |
| `WP_ADMIN_EMAIL` | Administrator email |
| `WP_USER` | Login of the second user (role `author`) |
| `WP_USER_EMAIL` | Email of the second user |

## 2. Build and launch the project

### With the Makefile

| Target | What it runs |
|---|---|
| `make` / `make up` | Creates `/home/elal-hai/data/mariadb` and `/home/elal-hai/data/wordpress`, then `docker compose up -d --build` |
| `make stop` / `make start` | `docker compose stop` / `docker compose start` |
| `make down` (and `make clean`) | `docker compose down`: removes containers and network, keeps the data |
| `make fclean` | `down`, then `docker system prune -af`, removes the volumes and **deletes the stored data** |
| `make re` | `fclean` then `make` |

### With Docker Compose directly

```
docker compose -f srcs/docker-compose.yml up -d --build
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml down
```

To rebuild a single service after editing its files:

```
docker compose -f srcs/docker-compose.yml up -d --build nginx
```

## 3. Manage the containers and the volumes

### Containers

```
docker ps                          # running containers
docker logs -f wordpress           # follow the logs of a service
docker exec -it mariadb bash       # open a shell in a container
docker top nginx                   # processes (the main one is PID 1)
docker inspect nginx               # full configuration of a container
```

Open a database shell with the secret read inside the container:

```
docker exec -it mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)"'
```

Manage WordPress with WP-CLI:

```
docker exec wordpress wp user list --allow-root
docker exec wordpress wp core version --allow-root
```

### Volumes and network

```
docker volume ls
docker volume inspect srcs_mariadb_data      # shows the "device" path on the host
docker volume inspect srcs_wordpress_data
docker network ls
docker network inspect srcs_inception
```

Compose prefixes the names with the project name (`srcs`), hence `srcs_mariadb_data`.

## 4. Where the data is stored and how it persists

The stack uses two Docker **named volumes**. Their `driver_opts` in `srcs/docker-compose.yml` make the `local` driver store the data in the home directory of the host:

| Volume | Mounted in | Stored on the host |
|---|---|---|
| `mariadb_data` | `mariadb`: `/var/lib/mysql` | `/home/elal-hai/data/mariadb` |
| `wordpress_data` | `wordpress` and `nginx`: `/var/www/html` | `/home/elal-hai/data/wordpress` |

The two containers `wordpress` and `nginx` share `wordpress_data`: WordPress writes the files and NGINX serves them.

Persistence:

- `make down`, `make stop` and a reboot of the machine **keep** the data. The containers are recreated or restarted, and read the same folders again.
- `make fclean` deletes the data.
- On start, `mariadb/tools/init.sh` creates the database only if `/var/lib/mysql/<MYSQL_DATABASE>` does not exist yet. Otherwise it just starts `mysqld` on the existing data.
- On start, `wordpress/tools/setup.sh` installs WordPress only if `wp-config.php` does not exist yet. Otherwise it just starts `php-fpm`.

Consequence: changing a password in `secrets/` after the first start does not change the password already stored in the data (see `USER_DOC.md` for the procedure).

## 5. How the services are built

| Service | Base | Start script | Main process (PID 1) |
|---|---|---|---|
| `mariadb` | `debian:bookworm` | `tools/init.sh` | `mysqld` |
| `wordpress` | `debian:bookworm` | `tools/setup.sh` | `php-fpm8.2 -F` |
| `nginx` | `debian:bookworm` | `tools/setup.sh` | `nginx -g "daemon off;"` |

- Every start script finishes with `exec`, so the daemon replaces the script and receives the signals sent by Docker.
- `wordpress` reaches `mariadb` by its service name on the `inception` network. `nginx` reaches php-fpm with `fastcgi_pass wordpress:9000`.
- `php-fpm` listens on TCP port `9000` instead of a Unix socket, because NGINX runs in another container.
- `nginx` creates a self-signed certificate on its first start, and only allows `TLSv1.2` and `TLSv1.3`.
- The passwords reach the containers as files in `/run/secrets/`, and the scripts read them at start. No password is written in a Dockerfile.