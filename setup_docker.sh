#!/bin/bash

# Вихід при помилці
set -e

# Функції для виведення повідомлень
function echo_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

function echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
}

# Крок 0: Очистка Docker кешу
echo_info "Очистка Docker кешу (усі непотрібні кешовані збірки будуть видалені)..."
docker builder prune -af

# Крок 1: Перевірка встановлення Docker Compose v2
echo_info "Перевірка наявності Docker Compose v2..."
DOCKER_COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "not_installed")

if [ "$DOCKER_COMPOSE_VERSION" == "not_installed" ]; then
    echo_error "Docker Compose v2 не встановлено."
    read -p "Бажаєте встановити Docker Compose v2 зараз? (y/N): " -n 1 -r
    echo    # Переход на новий рядок
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo_info "Встановлення Docker Compose v2..."
        mkdir -p ~/.docker/cli-plugins/
        curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o ~/.docker/cli-plugins/docker-compose
        chmod +x ~/.docker/cli-plugins/docker-compose
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

# Крок 3: Побудова Docker образу
echo_info "Побудова Docker образу..."
docker compose build

# Крок 4: Запуск контейнера у фоновому режимі
echo_info "Запуск Docker контейнера у фоновому режимі..."
docker compose up -d

# Крок 5: Очікування запуску контейнера
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

# Крок 6: Перевірка існування та прав доступу до setup.sh
echo_info "Перевірка файлу 'setup.sh' всередині контейнера..."
docker exec code-app-1 ls -la /workspaces/CODE/.devcontainer/setup.sh || { echo_error "setup.sh не знайдено!"; exit 1; }

# Перевірка прав на виконання для bash
echo_info "Перевірка прав на виконання для bash..."
BASH_EXEC_PERM=$(docker exec code-app-1 stat -c "%A" /workspaces/CODE/.devcontainer/setup.sh | cut -c4)
if [[ "$BASH_EXEC_PERM" == "x" ]]; then
    echo_info "setup.sh має права на виконання для bash."
else
    echo_info "setup.sh не має прав на виконання для bash. Додаємо права."
    docker exec code-app-1 chmod +x /workspaces/CODE/.devcontainer/setup.sh
fi

# Налаштування кольорового та іконного prompt для bash
echo_info "Налаштування кольорового та іконного prompt для bash..."
docker exec code-app-1 bash -c 'cat << "EOF" >> /home/vscode/.bashrc
# Кольоровий та іконний PS1 для bash
# Визначення кольорів
RED="\[\e[31m\]"
GREEN="\[\e[32m\]"
YELLOW="\[\e[33m\]"
BLUE="\[\e[34m\]"
MAGENTA="\[\e[35m\]"
CYAN="\[\e[36m\]"
RESET="\[\e[0m\]"

# Іконка наприклад: ⚡ (U+26A1)
ICON="⚡"

# Функція для отримання Git бранчу
git_branch() {
  git branch 2>/dev/null | grep "^*" | sed "s/^* //"
}

# Налаштування PS1
export PS1="\n${GREEN}\u${RESET}@${CYAN}\h${RESET}:${BLUE}\w${RESET} \$(git_branch && echo -e \"${YELLOW}(\$(git_branch))${RESET}\") ${MAGENTA}${ICON}${RESET} \$ "
EOF'

# Налаштування кольорового та іконного prompt для zsh
echo_info "Налаштування кольорового та іконного prompt для zsh..."
docker exec code-app-1 bash -c '
# Встановлення Oh My Zsh, якщо ще не встановлено
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "[INFO] Встановлення Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Встановлення Powerlevel10k, якщо ще не встановлено
if [ ! -d "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    echo "[INFO] Встановлення Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $HOME/.oh-my-zsh/custom/themes/powerlevel10k
fi

# Зміна теми на Powerlevel10k в .zshrc
sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"powerlevel10k\/powerlevel10k\"/" $HOME/.zshrc

# Додавання плагінів
sed -i "s/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/" $HOME/.zshrc

# Встановлення плагінів zsh-autosuggestions та zsh-syntax-highlighting
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    echo "[INFO] Встановлення zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi

if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    echo "[INFO] Встановлення zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

# Налаштування Powerlevel10k та іконок
cat << "EOF" >> $HOME/.p10k.zsh
# Кольоровий та іконний PROMPT для zsh (Powerlevel10k)
autoload -U colors && colors
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status command_execution_time)
POWERLEVEL9K_CONTEXT_TEMPLATE='%n@%m'

# Іконка для prompt, наприклад: ⚡
POWERLEVEL9K_VCS_MODIFIED_FOREGROUND='magenta'
POWERLEVEL9K_VCS_UNTRACKED_FOREGROUND='yellow'
EOF

# Активувати налаштування
source $HOME/.zshrc
'

# Встановлення зручних плагінів для zsh
echo_info "Встановлення зручних плагінів для zsh..."
docker exec code-app-1 bash -c '
# Встановлення zsh-autosuggestions
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions $HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi

# Встановлення zsh-syntax-highlighting
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
fi

# Додавання плагінів до .zshrc
sed -i "s/^plugins=(.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/" $HOME/.zshrc
'

# Крок 7: Виведення ASCII арту "OLEG"
echo_info "Виведення ASCII арту 'OLEG'..."
docker exec code-app-1 bash -c 'cat << "EOF"

 _  __ _       _
| |/ /(_)____ (_)_ __ ___   __ _
| ' /| |_  / | | '_ ` _ \ / _` |
|  < | |/ /  | | | | | | | (_| |
|_|\_\_/___|_|_|_| |_| |_|\__,_|

  ____  _     ____  _   _
 / __ \| |   |  __|| | | |
| |  | | |   | |_  | |_| |
| |  | | |   |  _| |  _  |
| |__| | |___| |___| | | |
 \____/|_____|_____|_| |_|

   _    _     _               __  ____     __  _     ___ _____ _____
  /_\  | |   | |    _ __  _  \ \/ /\ \   / / | |   |_ _|  ___| ____|
 //_\\ | |   | |   | '_ \| | | \  /  \ \ / /  | |    | || |_  |  _|
/  _  \| |___| |___| | | | |_| /  \   \ V /   | |___ | ||  _| | |___
\_/ \_/|_____|_____|_| |_|\__, /_/\_\   \_/    |_____|___|_|   |_____|
                          |___/
EOF'

    # Крок 8: Опціональний вхід у контейнер
    read -p "Бажаєте увійти у контейнер 'code-app-1' зараз? (y/N): " -n 1 -r
        echo    # Переход на новий рядок
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo_info "Вхід у контейнер 'code-app-1'..."
            docker exec -it code-app-1 /bin/bash
        else
            echo_info "Ви можете увійти у контейнер пізніше за допомогою команди:"
            echo "docker exec -it code-app-1 /bin/bash"
        fi

    echo_info "Автоматизація Docker завершена."