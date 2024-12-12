#!/bin/bash

# Enable debugging and error handling
set -e
set -u
set -o pipefail
[ "${BASH_VERSINFO:-0}" -ge 4 ] || { echo "Bash 4.0 or higher is required"; exit 1; }

# Функція для виведення інформаційних повідомлень
function echo_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

# Функція для виведення повідомлень про помилки
function echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# Крок 0: Очистка Docker кешу
echo_info "Очистка Docker кешу (усі непотрібні кешовані збірки будуть видалені)..."
docker builder prune -af

# Крок 1: Перевірка встановлення Docker Compose v2
echo_info "Перевірка наявності Docker Compose v2..."
DOCKER_COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "not_installed")

# Update error-prone sections
if [ "$DOCKER_COMPOSE_VERSION" = "not_installed" ]; then
    echo_error "Docker Compose v2 не встановлено."
    read -r -p "Бажаєте встановити Docker Compose v2 зараз? (y/N): " REPLY
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Встановлення Docker Compose v2..."
        if ! mkdir -p ~/.docker/cli-plugins/; then
            echo_error "Помилка створення директорії для Docker Compose"
            exit 1
        fi
        if ! curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose; then
            echo_error "Помилка завантаження Docker Compose"
            exit 1
        fi
        chmod +x ~/.docker/cli-plugins/docker-compose || exit 1
        echo_info "Docker Compose v2 встановлено."
    else
        echo_error "Встановлення Docker Compose v2 відхилено. Скрипт зупинено."
        exit 1
    fi
else
    echo_info "Docker Compose v2 встановлено. Версія: $DOCKER_COMPOSE_VERSION"
fi

# Крок 2: Перевірка та оновлення .dockerignore
DOCKERIGNORE_FILE=".dockerignore"

if [ -f "$DOCKERIGNORE_FILE" ]; then
    if grep -Fxq "!.devcontainer/" "$DOCKERIGNORE_FILE"; then
        echo_info "'!.devcontainer/' вже існує у $DOCKERIGNORE_FILE"
    else
        echo_info "Додаємо '!.devcontainer/' до $DOCKERIGNORE_FILE"
        echo "!.devcontainer/" >> "$DOCKERIGNORE_FILE"
    fi
else
    echo_info "$DOCKERIGNORE_FILE не знайдено. Створюємо і додаємо '!.devcontainer/'"
    echo "!.devcontainer/" > "$DOCKERIGNORE_FILE"
fi

# Крок 3: Створення директорії для Continue
echo_info "Створення директорії для Continue..."
mkdir -p .devcontainer/continue

# Add before Docker build step
echo_info "Cleaning up previous Docker resources..."
docker compose down --remove-orphans
docker system prune -f

# Крок 4: Побудова Docker образу
echo_info "Побудова Docker образу..."
docker compose build --no-cache

# Крок 5: Запуск контейнера у фоновому режимі
echo_info "Запуск Docker контейнера у фоновому режимі..."
docker compose up -d

# Крок 6: Очікування запуску 'code-app-1' контейнера...
echo_info "Очікування запуску 'code-app-1' контейнера..."
while true; do
    STATUS=$(docker inspect -f '{{.State.Running}}' code-app-1 2>/dev/null || echo "false")
    if [ "$STATUS" == "true" ]; then
        echo_info "'code-app-1' працює."
        break
    else
        echo_info "Чекаємо, поки 'code-app-1' запуститься..."
        sleep 2
    fi
done

# Крок 6.5: Зміна прав власності на /workspaces/CODE
echo_info "Зміна прав власності на /workspaces/CODE..."
docker exec code-app-1 sudo chown -R vscode:vscode /workspaces/CODE

# Надання права на виконання 'setup.sh'
echo_info "Надання права на виконання 'setup.sh'..."
docker exec code-app-1 chmod +x /workspaces/CODE/.devcontainer/setup.sh

# Запуск setup.sh всередині контейнера
echo_info "Запуск 'setup.sh' всередині контейнера..."
docker exec code-app-1 /workspaces/CODE/.devcontainer/setup.sh || { echo_error "Помилка при виконанні setup.sh!"; exit 1; }

# Перевірка віртуального середовища після setup.sh
echo_info "Verifying virtual environment..."
docker exec code-app-1 bash -c '[ -d "/workspaces/CODE/venv" ] || { echo "Virtual environment not found"; exit 1; }'
echo_info "Virtual environment verified successfully"

# Налаштування кольорового та іконного prompt для bash
echo_info "Налаштування кольорового та іконного prompt для bash..."
docker exec code-app-1 bash -c 'echo "
# Кольоровий та іконний PS1 для bash
RED=\"\[\e[31m\]\"
GREEN=\"\[\e[32m\]\"
YELLOW=\"\[\e[33m\]\"
BLUE=\"\[\e[34m\]\"
MAGENTA=\"\[\e[35m\]\"
CYAN=\"\[\e[36m\]\"
RESET=\"\[\e[0m\]\"

git_branch() {
    git branch 2>/dev/null | grep \"^*\" | cut -c3-
}

export PS1=\"\${MAGENTA}vscode\${RESET} \${CYAN}CODE\${RESET}\$(git_branch | grep . && echo \" \${YELLOW}(\$(git_branch))\${RESET}\")\$ \"
" >> /home/vscode/.bashrc'

# Налаштування Oh My Zsh та плагінів
echo_info "Налаштування Oh My Zsh та плагінів..."
docker exec -i code-app-1 zsh << 'EOF'
    # Встановлення Oh My Zsh
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "[INFO] Встановлення Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Встановлення плагінів
    for plugin in "zsh-autosuggestions" "zsh-syntax-highlighting"; do
        if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/$plugin" ]; then
            echo "[INFO] Встановлення $plugin..."
            git clone "https://github.com/zsh-users/$plugin.git" "$HOME/.oh-my-zsh/custom/plugins/$plugin"
        fi
    done

    # Встановлення Powerlevel10k
    if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
        echo "[INFO] Встановлення Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    fi

    # Налаштування .zshrc
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$HOME/.zshrc"
    sed -i 's/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' "$HOME/.zshrc"

    # Додавання налаштувань Powerlevel10k до .zshrc
    cat << 'EOL' >> "$HOME/.zshrc"
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Pre-configured Powerlevel10k settings
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs time)
EOL

    # Створення файлу конфігурації Powerlevel10k
    cat << 'EOL' > "$HOME/.p10k.zsh"
# Powerlevel10k configuration file. Generated by `p10k configure`.
# Based on the configuration wizard choices, you can customize this file further.
POWERLEVEL9K_MODE='nerdfont-complete'
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
POWERLEVEL9K_RPROMPT_ON_NEWLINE=false
POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX=''
POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%F{blue}❯%f '
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time background_jobs time)
POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'
POWERLEVEL9K_DIR_ANCHOR_BOLD=true
POWERLEVEL9K_DIR_ANCHOR_FOREGROUND='blue'
POWERLEVEL9K_DIR_ANCHOR_BACKGROUND='black'
POWERLEVEL9K_VCS_MODIFIED_BACKGROUND='yellow'
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='black'
POWERLEVEL9K_VCS_UNTRACKED_BACKGROUND='red'
POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='black'
POWERLEVEL9K_VCS_CLEAN_BACKGROUND='green'
POWERLEVEL9K_VCS_CLEAN_FOREGROUND='black'
EOL

    source "$HOME/.zshrc"
EOF

# Крок 10: Перевідкриття проекту в контейнері
echo_info "Налаштування завершено."
read -p "Бажаєте перевідкрити проект у VS Code Dev Container? (y/N): " -n 1 -r
echo    # Перехід на новий рядок
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo_info "Спроба відкрити проект у VS Code Dev Container..."

    # Try different VS Code socket paths
    VSCODE_IPC_HOOK_CLI=$(find /run/user/$(id -u) -name "vscode-ipc-*.sock" 2>/dev/null | head -n 1)

    if [ -n "$VSCODE_IPC_HOOK_CLI" ]; then
        echo_info "Знайдено VS Code socket: $VSCODE_IPC_HOOK_CLI"
        if ! VSCODE_IPC_HOOK_CLI="$VSCODE_IPC_HOOK_CLI" code --folder-uri "vscode-remote://dev-container+${PWD}/workspaces/CODE" 2>/dev/null; then
            echo_error "Помилка при відкритті VS Code"
        fi
    else
        echo_error "VS Code socket не знайдено"
    fi

    # Fallback to shell access
    echo_info "Використовуйте наступні альтернативні команди:"
    echo "1. Для доступу до контейнера через командний рядок:"
    echo "   docker exec -it code-app-1 /bin/zsh"
    echo "2. Для відкри��тя в VS Code пізніше:"
    echo "   code --folder-uri \"vscode-remote://dev-container+code-app-1/workspaces/CODE\""

    # Automatically open shell if VS Code fails
    docker exec -it code-app-1 /bin/zsh
fi

# Додаємо інформацію про альтернативний доступ
echo_info "Контейнер успішно налаштовано. Доступні команди:"
echo "# Direct zsh access (recommended):"
echo "docker exec -it code-app-1 /bin/zsh"
echo ""
echo "# Direct bash access:"
echo "docker exec -it code-app-1 /bin/bash"
echo ""
echo "# Direct workspace access with bash:"
echo "docker exec -it code-app-1 /bin/bash -c \"cd /workspaces/CODE && exec /bin/bash\""

# Оновлене середовище
export LAMMA_HOST="http://172.17.0.1:11434"

echo "
        _  __ _       _
        | |/ /(_)____ (_)_ __ ___   __ _
        | ' /| |_  / | | '_ \` _ \ / _\` |
        |  < | |/ /  | | | | | | | (_| |
        |_|\_\_/___|_|_|_| |_| |_|\__,_|

        ____  _     ____  _   _
        / __ \| |   |  __|| | | |
        | |  | | |   | |_  | |_| |
        | |  | | |   |  _| |  _  |
        | |__| | |___| |___| | | |
        \____/|_____|_____|_| |_|
                                OLEG
        ....is now installed!
"