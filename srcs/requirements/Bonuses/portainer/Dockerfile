FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    wget \
    tar \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/portainer
WORKDIR /opt/portainer

RUN wget https://github.com/portainer/portainer/releases/download/2.16.2/portainer-2.16.2-linux-amd64.tar.gz && \
    tar -xvf portainer-2.16.2-linux-amd64.tar.gz --strip-components=1 && \
    rm portainer-2.16.2-linux-amd64.tar.gz

EXPOSE 9443

ENTRYPOINT ["/opt/portainer/portainer"]
