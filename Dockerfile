FROM debian:bookworm-slim
WORKDIR /app

RUN apt-get update && apt-get install -y \
    ca-certificates \
    antiword \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

COPY config/              ./config/
COPY ignore/              ./ignore/
COPY TracyServer          ./TracyServer
COPY TracyServer.sha256   ./TracyServer.sha256
COPY .sql                 ./.sql
COPY static/              ./static/
COPY exe/                 ./exe/

RUN chmod +x ./TracyServer

RUN mkdir -p /data/database
VOLUME ["/data/database"]

ARG PORT
EXPOSE ${PORT}
ENTRYPOINT ["/app/TracyServer"]