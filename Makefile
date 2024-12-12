include .env
export

.PHONY: build start stop clean logs shell setup shell-zsh shell-bash workspace-bash

build:
	docker compose build --no-cache

start:
	docker compose up -d

stop:
	docker compose down

clean:
	docker compose down --remove-orphans
	docker system prune -f

logs:
	docker compose logs -f

shell:
	@if docker container inspect code-app-1 >/dev/null 2>&1; then \
		if ! docker exec -it code-app-1 /bin/zsh; then \
			echo "Falling back to bash..."; \
			docker exec -it code-app-1 /bin/bash; \
		fi \
	else \
		echo "Container 'code-app-1' is not running. Starting it..."; \
		docker compose up -d && docker exec -it code-app-1 /bin/zsh || docker exec -it code-app-1 /bin/bash; \
	fi

shell-zsh:
	docker exec -it code-app-1 /bin/zsh

shell-bash:
	docker exec -it code-app-1 /bin/bash

workspace:
	@if docker container inspect code-app-1 >/dev/null 2>&1; then \
		docker exec -it code-app-1 /bin/bash -c "cd /workspaces/CODE && exec /bin/bash"; \
	else \
		echo "Container 'code-app-1' is not running."; \
		exit 1; \
	fi

workspace-bash:
	docker exec -it code-app-1 /bin/bash -c "cd /workspaces/CODE && exec /bin/bash"

# Initial setup and permissions
init:
	chmod +x SDK.sh
	chmod +x .devcontainer/setup.sh

setup: init
	./SDK.sh || { \
		echo "Setup completed with warnings. Container is ready but VS Code connection failed."; \
		make shell; \
		exit 0; \
	}

format:
	black . && isort . && prettier --write .

lint:
	pylint src && mypy src && eslint .

test:
	pytest

all: format lint test

help:
	@echo "Available commands:"
	@echo "  make shell-zsh         # Direct zsh access (recommended)"
	@echo "  make shell-bash        # Direct bash access"
	@echo "  make workspace-bash    # Direct workspace access with bash"