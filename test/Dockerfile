FROM bats/bats:latest
RUN apk add --no-cache git coreutils
WORKDIR /work
COPY . /work
ENTRYPOINT ["bats"]
