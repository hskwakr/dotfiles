FROM bats/bats:latest

# Install tools required by tests
RUN apk add --no-cache git

WORKDIR /work
COPY . /work
ENTRYPOINT ["bats"]
