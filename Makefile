.PHONY: help start stop nuke update info build-local start-local stop-local update-local nuke-local db-drop-local

help:
	@echo "Ethernal Docker Management"
	@echo ""
	@echo "Remote Images (pulls from Docker Hub):"
	@echo "  make start     - Pull images and start all services"
	@echo "  make stop      - Stop all services"
	@echo "  make update    - Pull latest images and restart"
	@echo "  make nuke      - Remove everything including volumes"
	@echo ""
	@echo "Local Build (builds from source code):"
	@echo "  make build-local   - Build Docker images from local source"
	@echo "  make start-local   - Build and start all services locally"
	@echo "  make stop-local    - Stop locally-built services"
	@echo "  make update-local  - Rebuild and restart from local source"
	@echo "  make nuke-local    - Remove everything including volumes"
	@echo "  make db-drop-local - Force-drop DB only (keeps volume; DB recreated on next start)"
	@echo ""
	@echo "Other:"
	@echo "  make info      - Show connection info"

start:
	@if [ -n "$$(docker compose -f docker-compose.prod.yml ps -q)" ]; then \
		echo "Stopping and removing running containers..."; \
		docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod down --remove-orphans; \
	fi
	@if [ ! -f run/.env.prod ] || [ ! -f pm2-server/.env.prod ] || [ ! -f .env.docker-compose.prod ]; then \
		echo "Generating environment and config files (interactive: domain and port)..."; \
		bash ./generate-env-files.sh; \
	else \
		echo "All environment and config files already exist. Skipping generation."; \
	fi
	@echo "Pulling latest images for all services..."
	docker compose -f docker-compose.prod.yml pull
	@echo "Starting up the application..."
	docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod up -d
	@echo "Waiting for backend container to be healthy..."
	@docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod exec backend sh -c 'until nc -z localhost 8888; do sleep 1; done'
	@DB_NAME=$$(grep '^DB_NAME=' run/.env.prod | cut -d '=' -f2); \
	if docker compose -f docker-compose.prod.yml exec -T postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$$DB_NAME'" | grep -q 1; then \
		echo "Database '$$DB_NAME' already exists. Skipping creation."; \
	else \
		docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:create; \
	fi
	@echo "Running sequelize migrations in backend container..."
	docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:migrate
	docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:seed:all
	@$(MAKE) info

stop:
	@echo "Stopping and cleaning up all containers and networks..."
	docker compose -f docker-compose.prod.yml down --remove-orphans 

nuke:
	@echo "Nuking everything: containers, networks, volumes, and generated env/config files..."
	docker compose -f docker-compose.prod.yml down --remove-orphans --volumes
	rm -f .env.prod run/.env.prod pm2-server/.env.prod
	rm -f pgbouncer/.env.pgbouncer.prod pgbouncer/userlist.txt pgbouncer/pgbouncer.ini

update:
	@echo "Pulling latest images for all services..."
	docker compose -f docker-compose.prod.yml pull
	@echo "Recreating containers with latest images..."
	docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod up -d --force-recreate
	@echo "Waiting for backend container to be healthy..."
	@docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod exec backend sh -c 'until nc -z localhost 8888; do sleep 1; done'
	@echo "Running sequelize migrations in backend container..."
	docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:migrate
	@echo "Running sequelize seeds in backend container..."
	docker compose -f docker-compose.prod.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:seed

# ============ LOCAL BUILD TARGETS ============

build-local:
	@echo "Building Docker images from local source..."
	docker compose -f docker-compose.local.yml build

start-local:
	@if [ ! -f run/.env.prod ] || [ ! -f pm2-server/.env.prod ] || [ ! -f .env.docker-compose.prod ]; then \
		echo "Generating environment and config files (APP_URL=localhost, port 80)..."; \
		APP_URL=localhost EXPOSED_PORT=80 ENABLE_SSL=false bash ./generate-env-files.sh; \
	else \
		echo "All environment and config files already exist. Skipping generation."; \
	fi
	@if [ -n "$$(docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod ps -q)" ]; then \
		echo "Stopping and removing running containers..."; \
		docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod down --remove-orphans; \
	fi
	@echo "Building Docker images from local source..."
	docker compose -f docker-compose.local.yml build
	@echo "Starting up the application..."
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod up -d
	@echo "Waiting for backend to be ready (up to 180s)..."
	@i=0; while [ $$i -lt 180 ]; do \
		if docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec -T backend sh -c 'nc -z localhost 8888' 2>/dev/null; then \
			echo "Backend is ready."; break; \
		fi; \
		i=$$((i+1)); \
		if [ $$i -eq 180 ]; then \
			echo "Error: Backend did not become ready in 180s. Check 'docker compose -f docker-compose.local.yml logs backend'. On low-memory hosts (e.g. 4GB) the stack may need more time or swap."; \
			exit 1; \
		fi; \
		sleep 1; \
	done
	@DB_NAME=$$(grep '^DB_NAME=' run/.env.prod | cut -d '=' -f2); \
	if docker compose -f docker-compose.local.yml exec -T postgres psql -U postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$$DB_NAME'" | grep -q 1; then \
		echo "Database '$$DB_NAME' already exists. Skipping creation."; \
	else \
		docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:create; \
	fi
	@echo "Running sequelize migrations in backend container..."
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:migrate
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:seed:all
	@$(MAKE) info

stop-local:
	@echo "Stopping and cleaning up all containers and networks..."
	docker compose -f docker-compose.local.yml down --remove-orphans

update-local:
	@echo "Rebuilding Docker images from local source..."
	docker compose -f docker-compose.local.yml build
	@echo "Recreating containers with new images..."
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod up -d --force-recreate
	@echo "Waiting for backend to be ready (up to 180s)..."
	@i=0; while [ $$i -lt 180 ]; do \
		if docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec -T backend sh -c 'nc -z localhost 8888' 2>/dev/null; then \
			echo "Backend is ready."; break; \
		fi; \
		i=$$((i+1)); \
		if [ $$i -eq 180 ]; then \
			echo "Error: Backend did not become ready in 180s. Check backend logs."; exit 1; \
		fi; \
		sleep 1; \
	done
	@echo "Running sequelize migrations in backend container..."
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:migrate
	@echo "Running sequelize seeds in backend container..."
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec backend npx sequelize db:seed

nuke-local:
	@echo "Nuking everything: containers, networks, volumes, and generated env/config files..."
	@if [ -f .env.docker-compose.prod ]; then \
		docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod down --remove-orphans --volumes; \
	else \
		docker compose -f docker-compose.local.yml down --remove-orphans --volumes; \
	fi
	@VOLUME_NAME=$$(basename $$(pwd))_db; \
	echo "Removing volume $$VOLUME_NAME if present..."; \
	docker volume rm $$VOLUME_NAME 2>/dev/null || true
	rm -f .env.prod run/.env.prod pm2-server/.env.prod
	rm -f pgbouncer/.env.pgbouncer.prod pgbouncer/userlist.txt pgbouncer/pgbouncer.ini

# Force-drop the ethernal database (keeps volume; on next start-local the DB will be recreated). Requires postgres to be running.
db-drop-local:
	@if [ ! -f run/.env.prod ]; then echo "Run make start-local once to generate run/.env.prod"; exit 1; fi
	@DB_NAME=$$(grep '^DB_NAME=' run/.env.prod | cut -d '=' -f2); \
	echo "Dropping database \"$$DB_NAME\"..."; \
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec -T postgres psql -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$$DB_NAME' AND pid <> pg_backend_pid();" 2>/dev/null; \
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec -T postgres psql -U postgres -c "DROP DATABASE IF EXISTS \"$$DB_NAME\";"; \
	docker compose -f docker-compose.local.yml --env-file .env.docker-compose.prod exec -T postgres psql -U postgres -c "CREATE DATABASE \"$$DB_NAME\";"; \
	echo "Database dropped and recreated. Run migrations (or restart backend) to reapply schema."

# ============ INFO ============

info:
	@sh -c '\
	is_domain() { \
	  case "$$1" in \
	    *[a-zA-Z]*) return 0 ;; \
	    *) return 1 ;; \
	  esac; \
	}; \
	DOMAIN=$$(grep "^APP_DOMAIN=" run/.env.prod | cut -d "=" -f2); \
	if [ -z "$$DOMAIN" ]; then \
	  APP_URL=$$(grep "^APP_URL=" run/.env.prod | cut -d "=" -f2); \
	  EXPOSED_PORT=$$(grep "^EXPOSED_PORT=" .env.docker-compose.prod | cut -d "=" -f2); \
	  if [ -z "$$EXPOSED_PORT" ] || [ "$$EXPOSED_PORT" = "80" ]; then \
	    DOMAIN="$$APP_URL"; \
	  else \
	    DOMAIN="$$APP_URL:$$EXPOSED_PORT"; \
	  fi; \
	fi; \
	DB_USER=$$(grep "^DB_USER=" run/.env.prod | cut -d "=" -f2); \
	DB_PASSWORD=$$(grep "^DB_PASSWORD=" run/.env.prod | cut -d "=" -f2); \
	DB_NAME=$$(grep "^DB_NAME=" run/.env.prod | cut -d "=" -f2); \
	DB_HOST=$$(grep "^DB_HOST=" run/.env.prod | cut -d "=" -f2); \
	DB_PORT=$$(grep "^DB_PORT=" run/.env.prod | cut -d "=" -f2); \
	BULLBOARD_USERNAME=$$(grep "^BULLBOARD_USERNAME=" run/.env.prod | cut -d "=" -f2); \
	BULLBOARD_PASSWORD=$$(grep "^BULLBOARD_PASSWORD=" run/.env.prod | cut -d "=" -f2); \
	CONN_STR="postgresql://$$DB_USER:$$DB_PASSWORD@$$DB_HOST:$$DB_PORT/$$DB_NAME"; \
	echo ""; \
	echo "==================== Ethernal Installation Complete! ===================="; \
	echo ""; \
	if is_domain "$$DOMAIN"; then \
	  echo "🌐  DNS Setup Reminder:"; \
	  echo "    Make sure to add an A record in your DNS provider:"; \
	  echo "    $${DOMAIN} -> <your-server-ip-address>"; \
	  echo ""; \
	fi; \
	echo "🔗  Start here to setup your instance:"; \
	echo "    http://$$DOMAIN/setup"; \
	echo ""; \
	echo "🐘  PostgreSQL Connection String:"; \
	echo "    $$CONN_STR"; \
	echo ""; \
	echo "📊  Bullboard Access (background jobs):"; \
	echo "    http://$$DOMAIN/bull"; \
	echo "    Username: $$BULLBOARD_USERNAME"; \
	echo "    Password: $$BULLBOARD_PASSWORD"; \
	echo ""; \
	echo "==============================================================="; \
	echo ""; \
	'