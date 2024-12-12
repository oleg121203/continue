#!/bin/bash
set -e  # Завершити скрипт при першій помилці
set -u  # Завершити скрипт, якщо використовується незадекларована змінна
set -o pipefail  # Завершити скрипт, якщо будь-яка команда в пайпі завершується з помилкою

# Set up Git configuration
git config --global user.email "oleg1203@gmail.com"
git config --global user.name "Oleg Kizyma"

# Setup pre-commit
export PRE_COMMIT_HOME=/workspaces/CODE/.cache/pre-commit
mkdir -p $PRE_COMMIT_HOME
chmod -R 777 $PRE_COMMIT_HOME
pre-commit install

# Make script executable
chmod +x "${0}"

echo "Ініціалізація Git репозиторію..."
git init

# Створення та активація віртуального середовища
echo "Створення та активація віртуального середовища..."
python -m venv /workspaces/CODE/venv
if [ -d "/workspaces/CODE/venv" ]; then
    echo "Віртуальне середовище створено успішно."
else
    echo "Помилка: Не вдалося створити віртуальне середовище!"
    exit 1
fi

echo "Перевірка структури директорій після створення віртуального середовища:"
ls -la /workspaces/CODE

# Додамо функцію перевірки середовища та налаштування PS1
check_environment() {
    echo "=== Перевірка середовища ==="
    echo "Поточна оболонка: ${SHELL:-невідомо}"
    echo "VIRTUAL_ENV: ${VIRTUAL_ENV:-не встановлено}"
    echo "PWD: ${PWD:-невідомо}"
    echo "USER: ${USER:-$(whoami)}"  # Використовуємо whoami як запасний варіант
    echo "PATH: ${PATH:-невідомо}"

    # Налаштування PS1 для віртуального середовища
    # Кольори та іконки
    RED="\[\e[31m\]"
    GREEN="\[\e[32m\]"
    YELLOW="\[\e[33m\]"
    BLUE="\[\e[34m\]"
    MAGENTA="\[\e[35m\]"
    CYAN="\[\e[36m\]"
    RESET="\[\e[0m\]"
    VENV_ICON="🐍"
    GIT_ICON="⎇"

    # Функція для отримання Git бранчу
    git_branch() {
        git branch 2>/dev/null | grep "^*" | sed "s/^* //"
    }

    # Функція для відображення віртуального середовища
    venv_info() {
        [[ -n "$VIRTUAL_ENV" ]] && echo "(${VIRTUAL_ENV##*/}) "
    }

    # Налаштування PS1
    PS1="\n\$(venv_info)${CYAN}\w${RESET} \$(git_branch && echo \"${YELLOW}${GIT_ICON} \$(git_branch)${RESET}\") \n${MAGENTA}${VENV_ICON}${RESET} \$ "
}

# Встановлюємо USER якщо не визначено
: "${USER:=$(whoami)}"
export USER

source /workspaces/CODE/venv/bin/activate

# Перевірка, чи активовано віртуальне середовище
if [ -z "$VIRTUAL_ENV" ]; then
    echo "Помилка: Віртуальне середовище не активовано!"
    exit 1
else
    echo "Віртуальне середовище активовано: $VIRTUAL_ENV"
    # Додаємо ASCII арт
    cat << "EOF"
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

EOF

    echo "Віртуальне середовище готове до роботи!"
fi

check_environment

# Оновлення pip та встановлення залежностей
echo "Оновлення pip та встановлення залежностей..."
pip install --no-cache-dir --upgrade pip

if [ -f /workspaces/CODE/requirements.txt ]; then
    pip install --no-cache-dir -r /workspaces/CODE/requirements.txt
else
    echo "Файл requirements.txt не знайдено, пропускаємо встановлення залежностей."
fi

# Встановлення бібліотеки selenium
pip install selenium

echo "Віртуальне середовище створено та налаштовано."

echo "Встановлення Python-залежностей..."
if [ -f requirements.txt ]; then
    pip install --no-cache-dir -r requirements.txt
else
    echo "Файл requirements.txt не знайдено, пропускаємо встановлення Python-залежностей."
fi

# Изменяем установку pre-commit хуків
echo "Встановлення pre-commit хуків..."
if ! pre-commit install --install-hooks; then
    echo "Попередження: Виникли проблеми при встановленні pre-commit хуків"
    echo "Продовжуємо виконання..."
fi

echo "Створення директорії ~/.continue/lance..."
mkdir -p ~/.continue/lance

# Initialize NVM and Node.js
export NVM_DIR="/usr/local/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Add NVM initialization to shell rc files
echo 'export NVM_DIR="/usr/local/nvm"' >> ~/.zshrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.zshrc
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.zshrc

echo 'export NVM_DIR="/usr/local/nvm"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> ~/.bashrc
echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> ~/.bashrc

# Verify Node.js installation
if ! command -v node >/dev/null 2>&1; then
    echo "Node.js не встановлено, встановлюємо..."
    nvm install node
    nvm use node
fi

echo "Встановлення npm-залежностей..."
if command -v npm >/dev/null 2>&1; then
    npm install --save-dev @types/vscode @types/node @vscode/test-electron
else
    echo "Помилка: npm не знайдено після встановлення Node.js"
    exit 1
fi

echo "Налаштування SSH ключів..."
mkdir -p ~/.ssh_keys
cp -R ~/.ssh/* ~/.ssh_keys/
chmod 600 ~/.ssh_keys/id_rsa
chmod 644 ~/.ssh_keys/id_rsa.pub
eval "$(ssh-agent -s)"
ssh-add ~/.ssh_keys/id_rsa

echo "Всі команди виконані успішно!"