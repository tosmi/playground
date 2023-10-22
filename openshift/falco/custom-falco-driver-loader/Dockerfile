FROM docker.io/falcosecurity/falco-driver-loader:0.36.1

RUN apt update \
    && apt install -y libelf-dev \
    && rm -rf /var/lib/apt/list/*
