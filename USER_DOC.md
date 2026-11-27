# User documentation

This document explains how to use and administer the Inception stack, without needing to know how it is built. For the technical details, see `DEV_DOC.md`.

## 1. What the stack provides

| Service | What it does | How to reach it |
|---|---|---|
| **NGINX** | Web server. Receives every visit over HTTPS (TLS 1.2 or 1.3) and passes PHP requests to WordPress. | `https://elal-hai.42.fr` (port `443`) |
| **WordPress** | The website and its administration panel. Runs with php-fpm. | Only through NGINX |
| **MariaDB** | The database that stores the articles, pages and user accounts. | Only from inside the stack, not reachable from outside |

Only port `443` is open. Nothing else can be reached from outside the virtual machine.

## 2. Start and stop the project

All commands are run from the root of the repository, in the virtual machine.

| Goal | Command |
|---|---|
| Start everything (builds the images the first time) | `make` |
| Pause the services, keeping the containers | `make stop` |
| Resume paused services | `make start` |
| Stop and remove the containers (**data is kept**) | `make down` |
| Remove everything, **including the website data** | `make fclean` |
| Rebuild everything from scratch | `make re` |

The services restart by themselves after a crash or after a reboot of the virtual machine.

> Warning: `make fclean` and `make re` erase the database and the WordPress files stored in `/home/elal-hai/data`. Use them only to start over.

## 3. Access the website and the administration panel

1. Make sure the domain name points to the machine: the file `/etc/hosts` must contain `127.0.0.1 elal-hai.42.fr`.
2. Open `https://elal-hai.42.fr` in a browser for the public website.
3. Open `https://elal-hai.42.fr/wp-admin` for the administration panel, and sign in with the administrator account.

The certificate is self-signed, so the browser shows a warning the first time. Accept the exception to continue. Using `http://` does not work, because port `80` is closed.

Two accounts exist:

| Account | Role | What it can do |
|---|---|---|
| Administrator (`WP_ADMIN_USER`) | `administrator` | Manage the whole site: content, users, themes, settings |
| Second user (`WP_USER`) | `author` | Write and publish its own articles |

## 4. Locate and manage the credentials

Credentials are stored locally and are never committed to git.

| What | Where |
|---|---|
| Account names, domain, database name | `srcs/.env` (`WP_ADMIN_USER`, `WP_USER`, `DOMAIN_NAME`, ...) |
| WordPress passwords | `secrets/credentials.txt` (`WP_ADMIN_PASSWORD` and `WP_USER_PASSWORD`) |
| Database user password | `secrets/db_password.txt` |
| Database root password | `secrets/db_root_password.txt` |

To read a value, use `grep`, for example:

```
grep WP_ADMIN_USER srcs/.env
grep WP_ADMIN_PASSWORD secrets/credentials.txt
```

Write each line as `NAME=value`, without spaces around `=` and without `<` or `>` characters: everything after the `=` is the password.

### Change a WordPress password

Either use **Users > Profile** in the administration panel, or edit `secrets/credentials.txt` and apply it with:

```
docker exec wordpress sh -c 'wp user update "$WP_ADMIN_USER" --user_pass="$(grep "^WP_ADMIN_PASSWORD=" /run/secrets/credentials | cut -d= -f2-)" --allow-root'
```

(Use `WP_USER` and `WP_USER_PASSWORD` for the second account.) WordPress keeps its passwords in its own database, so editing the file alone is not enough.

### Change a database password

The database passwords are only read when the database is created. To change them, edit the files in `secrets/`, then run `make fclean` and `make`. This recreates the database, so the existing content is lost.

## 5. Check that the services are running

**1. The containers.**

```
docker ps
```

Three containers must be listed with the status `Up`: `nginx`, `wordpress` and `mariadb`. Only `nginx` shows a published port (`0.0.0.0:443->443/tcp`).

**2. The website.**

```
curl -kI https://elal-hai.42.fr
```

The answer must start with `HTTP/1.1 200 OK`.

**3. The database.**

```
docker exec mariadb sh -c 'mariadb -uroot -p"$(cat /run/secrets/db_root_password)" -e "SHOW DATABASES;"'
```

The list must contain the `wordpress` database.

**4. The logs, when something looks wrong.**

```
docker logs nginx
docker logs wordpress
docker logs mariadb
```

### Common problems

| Symptom | Likely cause and fix |
|---|---|
| The browser cannot find `elal-hai.42.fr` | The `/etc/hosts` line is missing. Add it. |
| Connection refused on `http://` | Normal. Use `https://`. |
| Security warning in the browser | Normal: the certificate is self-signed. Accept it. |
| WordPress rejects the password | The password in `secrets/credentials.txt` differs from the one stored in the database. See "Change a WordPress password". |
| A container is not `Up` | Read its logs with `docker logs`, then run `make down` and `make`. |