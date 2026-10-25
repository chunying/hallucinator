FROM rust:alpine AS builder

RUN apk update && apk upgrade && apk add \
	curl unzip git python3 py3-pygments pkgconfig musl-dev make g++ fontconfig-dev clang22-libclang

ENV RUSTFLAGS="-C target-feature=-crt-static"

RUN mkdir /build
RUN cd /build && git clone https://github.com/gianlucasb/hallucinator.git
WORKDIR /build/hallucinator/hallucinator-rs
RUN cargo build --release
#RUN mkdir -p /usr/local/bin && cp ./target/release/hallucinator-tui ./target/release/hallucinator-cli /usr/local/bin
WORKDIR /

FROM alpine:latest AS runtime

RUN apk update && apk upgrade && apk add --no-cache tini bash htop neovim musl-locales musl-locales-lang \
		fontconfig freetype libstdc++ libbz2

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

WORKDIR /
COPY --from=builder /build/hallucinator/hallucinator-rs/target/release/hallucinator-tui /usr/bin
COPY --from=builder /build/hallucinator/hallucinator-rs/target/release/hallucinator-cli /usr/bin

COPY profile /etc/profile.d/99-profile.sh
RUN chmod 755 /etc/profile.d/99-profile.sh

RUN mkdir -p /home/.local/share
RUN (cd /home/.local/share/; ln -sf /db ./hallucinator)
RUN chmod 1777 /home

COPY tini.sh /sbin/tini.sh
RUN chmod 755 /sbin/tini.sh
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/sbin/tini.sh", "--" ]
CMD [ "/bin/bash", "/entrypoint.sh" ]
