FROM bats/bats:latest

# Install tools required by tests
RUN apt-get update \
    && apt-get install -y git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY . /work
ENTRYPOINT ["bats"]
