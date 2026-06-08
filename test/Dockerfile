FROM bats/bats:latest
RUN apk add --no-cache git coreutils jq
WORKDIR /work
COPY . /work
ENTRYPOINT ["bats"]
