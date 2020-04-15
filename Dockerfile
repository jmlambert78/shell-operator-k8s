# build libjq
FROM ubuntu:18.04 AS libjq
ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    LC_ALL=C.UTF-8 \
    LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y git ca-certificates && \
    git clone https://github.com/jmlambert78/libjq-go /libjq-go && \
    cd /libjq-go && \
    git submodule update --init --recursive && \
    /libjq-go/scripts/install-libjq-dependencies-ubuntu.sh && \
    /libjq-go/scripts/build-libjq-static.sh /libjq-go /libjq


# build shell-operator binary
FROM golang:1.12 AS shell-operator
ARG appVersion=latest

# Cache-friendly download of go dependencies.
ADD go.mod go.sum /src/shell-operator/
WORKDIR /src/shell-operator
RUN go mod download

COPY --from=libjq /libjq /libjq
ADD . /src/shell-operator

RUN CGO_ENABLED=1 \
    CGO_CFLAGS="-I/libjq/include" \
    CGO_LDFLAGS="-L/libjq/lib" \
    GOOS=linux \
    go build -ldflags="-s -w -X 'github.com/flant/shell-operator/pkg/app.Version=$appVersion'" \
             -o shell-operator \
             ./cmd/shell-operator


# build final image
FROM registry.suse.com/suse/sle15:15.1
RUN zypper --gpg-auto-import-keys ref -s
LABEL maintainer=jean-marc.lambert@suse.com
RUN zypper -n in wget jq && \
    wget https://storage.googleapis.com/kubernetes-release/release/v1.17.4/bin/linux/amd64/kubectl -O /bin/kubectl && \
    chmod +x /bin/kubectl && \
    mkdir /hooks
ADD frameworks /
COPY --from=shell-operator /src/shell-operator /
WORKDIR /
ENV SHELL_OPERATOR_HOOKS_DIR /hooks
ENV LOG_TYPE json
ENTRYPOINT ["/shell-operator"]
CMD ["start"]
