*This project has been created as part of the 42 curriculum by elal-hai.*

# Inception

## Description

Inception is a system administration project from the 42 curriculum. The goal is to build a small web infrastructure with **Docker Compose**, inside a **virtual machine**, where every service runs in its own container built from our own Dockerfiles.

The stack is made of three services:

| Service | Role | Exposed |
|---|---|---|
| `nginx` | Web server, the only entry point. Serves HTTPS with TLS 1.2 or TLS 1.3 only. | port `443` |
| `wordpress` | WordPress and php-fpm (no web server inside). Runs the PHP code. | `9000` (internal) |
| `mariadb` | MariaDB database used by WordPress. | `3306` (internal) |

Two Docker named volumes keep the data (the database and the WordPress files), and a dedicated Docker network connects the containers. All images are built from `debian:bookworm` (the penultimate stable Debian release). No ready-made image is pulled.

## Instructions

### Prerequisites

- A Debian virtual machine with Docker Engine, the Docker Compose plugin, `make` and `git`.
- The domain name `elal-hai.42.fr` pointing to the local machine. Add this line to `/etc/hosts`:

```
127.0.0.1 elal-hai.42.fr
```

### Configuration

Credentials are never stored in the repository. They are ignored by git (`.gitignore`) and must be created locally before the first start.

1. Create the `secrets/` folder at the root of the repository with three files:
   - `secrets/db_root_password.txt`: the MariaDB root password (one line).
   - `secrets/db_password.txt`: the password of the WordPress database user (one line).
   - `secrets/credentials.txt`: the WordPress passwords, two lines: `WP_ADMIN_PASSWORD=...` and `WP_USER_PASSWORD=...`.
2. Create `srcs/.env` with the non-sensitive configuration (replace the example values; the administrator login must not contain "admin" or "administrator"):

```
DOMAIN_NAME=elal-hai.42.fr
MYSQL_DATABASE=wordpress
MYSQL_USER=wpuser
WP_TITLE=Inception
WP_ADMIN_USER=wpmaster
WP_ADMIN_EMAIL=wpmaster@example.com
WP_USER=wpauthor
WP_USER_EMAIL=wpauthor@example.com
```

### Build and run

From the root of the repository:

| Command | Effect |
|---|---|
| `make` | Create the data folders, build the images and start the containers. |
| `make stop` / `make start` | Stop or restart the containers without removing them. |
| `make down` | Stop and remove the containers and the network. The data is kept. |
| `make fclean` | Remove everything: containers, images, volumes **and the stored data**. |
| `make re` | Full rebuild from scratch (`fclean` then `make`). |

### Access

- Website: `https://elal-hai.42.fr`
- Administration panel: `https://elal-hai.42.fr/wp-admin`

The TLS certificate is self-signed, so the browser shows a security warning the first time. Accept it to continue. Port `80` is closed on purpose: everything goes through `443`.

See `USER_DOC.md` for daily usage and `DEV_DOC.md` for development details.

## Project description

### Use of Docker and project sources

```
.
├── Makefile
├── secrets/                 (ignored by git)
└── srcs/
    ├── docker-compose.yml
    ├── .env                 (ignored by git)
    └── requirements/
        ├── mariadb/   Dockerfile, conf/50-server.cnf, tools/init.sh
        ├── wordpress/ Dockerfile, tools/setup.sh
        └── nginx/     Dockerfile, conf/nginx.conf, tools/setup.sh
```

- Each service has its own Dockerfile, and the image has the same name as the service.
- `srcs/docker-compose.yml` declares the three services, the two volumes, the network and the secrets. The `Makefile` calls it, so a single `make` builds and starts everything.
- Each container starts with a small script that prepares the service and then ends with `exec`, so the real daemon (`mysqld`, `php-fpm`, `nginx`) becomes PID 1. No `tail -f`, `sleep infinity` or infinite loop is used to keep a container alive.
- `mariadb/tools/init.sh` creates the database and its user on the first start, using the passwords read from the secrets.
- `wordpress/tools/setup.sh` waits for the database (a bounded loop of 30 tries), then installs WordPress with WP-CLI on the first start only, and creates the two users.
- `nginx/tools/setup.sh` generates a self-signed certificate and injects the domain name into `nginx.conf`.
- `restart: always` restarts a container after a crash.

### Virtual Machines vs Docker

A virtual machine emulates a whole computer and runs its own operating system and kernel on top of a hypervisor. It is heavy, slow to start and uses a lot of memory. A Docker container only isolates a process (and its files and network) and shares the kernel of the host. It is light, starts in seconds and is easy to reproduce from a Dockerfile. In this project the virtual machine is the host that runs Docker, and each service is a container inside it.

### Secrets vs Environment Variables

Environment variables are simple, but their values appear in `docker inspect` and in the environment of the process, so they are easy to leak. Docker secrets are mounted as files in `/run/secrets/` inside the container, and are not stored in the image nor shown by `docker inspect`. This project uses secrets for every password and `srcs/.env` only for non-sensitive configuration (domain name, database name, user names).

### Docker Network vs Host Network

With a Docker bridge network, the containers live in an isolated network and reach each other by service name (`mariadb`, `wordpress`). Only the ports explicitly published are reachable from outside; here only `443` on `nginx`. With the host network, a container shares the network stack of the host, with no isolation and a higher risk of port conflicts. It is forbidden by the subject, so the `inception` network is used.

### Docker Volumes vs Bind Mounts

A Docker volume is managed by Docker, has a name and does not depend on the folder layout of the host. A bind mount maps an existing host path directly into the container and relies on that path and its permissions. The subject requires named volumes, so `mariadb_data` and `wordpress_data` are declared in the `volumes:` section. Their `driver_opts` tell the `local` driver to store the data in `/home/elal-hai/data/mariadb` and `/home/elal-hai/data/wordpress` on the host, which keeps the data easy to find while remaining named volumes.

## Resources

### References

- Docker documentation: https://docs.docker.com/ (Dockerfile best practices, Compose file reference, volumes, networks, secrets)
- NGINX documentation: https://nginx.org/en/docs/ (TLS and FastCGI configuration)
- WP-CLI documentation: https://developer.wordpress.org/cli/commands/
- MariaDB knowledge base: https://mariadb.com/kb/
- PHP-FPM documentation: https://www.php.net/manual/en/install.fpm.php

### Use of AI

An AI assistant was used throughout the project to:

- explain the concepts (containers, PID 1, volumes, secrets, TLS, FastCGI),
- guide the work step by step and review the configuration files,
- help diagnose errors from the logs (for example a wrong WordPress password stored in `credentials.txt`),
- draft the documentation files, which were then reviewed by the author.

The files were created and tested in the virtual machine by the author, and every part of the project can be explained and modified without the assistant.