ARG ALPINE_IMAGE=docker.io/library/alpine:3.22@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce
ARG UBUNTU_IMAGE=docker.io/library/ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517

FROM ${ALPINE_IMAGE} AS chezmoi
ARG CHEZMOI_VERSION=2.70.5
RUN set -eu; \
    case "$(uname -m)" in \
      x86_64) \
        archive="chezmoi_${CHEZMOI_VERSION}_linux_amd64.tar.gz"; \
        checksum="6a76a0ac3718f0d45b34b4b57067f9556f8f6042e3da710a3c496838362aca14" \
        ;; \
      aarch64) \
        archive="chezmoi_${CHEZMOI_VERSION}_linux_arm64.tar.gz"; \
        checksum="4f4f31d0a10ed3b955e814a5ae20075426e27c9d3a09f536bfa4a6c8718353f2" \
        ;; \
      *) \
        printf 'unsupported architecture: %s\n' "$(uname -m)" >&2; \
        exit 1 \
        ;; \
    esac; \
    url="https://github.com/twpayne/chezmoi/releases/download/v${CHEZMOI_VERSION}/${archive}"; \
    wget -qO "/tmp/${archive}" "$url"; \
    printf '%s  %s\n' "$checksum" "/tmp/${archive}" | sha256sum -c -; \
    tar xzf "/tmp/${archive}" -C /usr/local/bin chezmoi; \
    rm "/tmp/${archive}"; \
    chezmoi --version

FROM ${UBUNTU_IMAGE} AS ubuntu
COPY --from=chezmoi /usr/local/bin/chezmoi /usr/local/bin/chezmoi
RUN chezmoi --version

FROM ${ALPINE_IMAGE} AS alpine
COPY --from=chezmoi /usr/local/bin/chezmoi /usr/local/bin/chezmoi
RUN chezmoi --version

FROM ${UBUNTU_IMAGE} AS ubuntu-bootstrap
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && ! command -v git \
    && ! command -v chezmoi \
    && mkdir -p /home/test \
    && chown 65532:65532 /home/test

FROM ${ALPINE_IMAGE} AS alpine-bootstrap
RUN ! command -v git \
    && ! command -v chezmoi \
    && mkdir -p /home/test \
    && chown 65532:65532 /home/test
