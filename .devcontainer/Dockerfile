FROM python:3.10 as builder

# Install system utilities with cleanup
RUN apt-get update && apt-get install -y \
    curl \
    zsh \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js using nvm
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 20.11.1
RUN mkdir -p $NVM_DIR && \
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm alias default $NODE_VERSION && \
    nvm use default

# Create final image
FROM python:3.10 as final

# Set up environment variables for Node.js
ENV NVM_DIR /usr/local/nvm
ENV NODE_VERSION 20.11.1
ENV PATH $NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Copy NVM and Node.js from builder
COPY --from=builder $NVM_DIR $NVM_DIR

ENV NODE_PATH $NVM_DIR/versions/node/v$NODE_VERSION/lib/node_modules

# Set up user, directories and permissions in a single layer
RUN apt-get update \
    && apt-get install -y sudo zsh git \
    && rm -rf /var/lib/apt/lists/* \
    && adduser --disabled-password --gecos "" vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode \
    && mkdir -p /workspaces/CODE/.devcontainer/continue \
    && chown -R vscode:vscode /workspaces \
    && chmod -R 755 /workspaces

# Copy and set permissions for setup script
COPY .devcontainer/setup.sh /workspaces/CODE/.devcontainer/setup.sh
RUN chown vscode:vscode /workspaces/CODE/.devcontainer/setup.sh \
    && chmod +x /workspaces/CODE/.devcontainer/setup.sh \
    && chown -R vscode:vscode /workspaces/CODE

USER vscode
WORKDIR /workspaces/CODE

ENV PATH="/workspaces/CODE/venv/bin:$PATH"
ENV VIRTUAL_ENV="/workspaces/CODE/venv"

CMD ["tail", "-f", "/dev/null"]