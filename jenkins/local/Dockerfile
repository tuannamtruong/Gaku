FROM jenkins/jenkins:lts-jdk21

USER root

# --- docker-ce-cli (lets Jenkins run docker commands via the host socket) ---
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg lsb-release && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) \
          signed-by=/etc/apt/keyrings/docker.gpg] \
          https://download.docker.com/linux/debian \
          $(lsb_release -cs) stable" \
        > /etc/apt/sources.list.d/docker.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce-cli docker-buildx-plugin && \
    rm -rf /var/lib/apt/lists/*

# --- kubectl (binary download — avoids Debian Trixie sqv v3-signature rejection) ---
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
        -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# --- minikube binary ---
RUN curl -fsSL -o /usr/local/bin/minikube \
        https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && \
    chmod +x /usr/local/bin/minikube

USER jenkins
