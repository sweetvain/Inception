COMPOSE = docker compose -f srcs/docker-compose.yml
DATA    = /home/elal-hai/data

all: up

up:
	mkdir -p $(DATA)/mariadb $(DATA)/wordpress
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

stop:
	$(COMPOSE) stop

start:
	$(COMPOSE) start

clean: down

fclean: down
	docker system prune -af
	docker volume rm srcs_mariadb_data srcs_wordpress_data 2>/dev/null || true
	sudo rm -rf $(DATA)/mariadb/* $(DATA)/wordpress/*

re: fclean all

.PHONY: all up down stop start clean fclean re