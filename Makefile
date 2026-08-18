NAME = inception
COMPOSE = srcs/docker-compose.yml

all: 
	@mkdir -p /home/aysadeq/data/mariadb
	@mkdir -p /home/aysadeq/data/wordpress
	@docker compose -f $(COMPOSE) up -d --build

down:
	@docker compose -f $(COMPOSE) down

clean:
	@docker compose -f $(COMPOSE) down -v

fclean: clean
	@docker compose -f $(COMPOSE) down -v --rmi all
	@sudo rm -rf /home/aysadeq/data/mariadb/*
	@sudo rm -rf /home/aysadeq/data/wordpress/*

re: fclean all

.PHONY: all down clean fclean re
