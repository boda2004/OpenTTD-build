ARG DISTRO=debian
ARG RELEASE=bullseye-slim
FROM ${DISTRO}:${RELEASE} as builder

ARG OPENTTD_RELEASE=12.0
ARG OPENGFX_RELEASE=7.1

ENV DEBIAN_FRONTEND=noninteractive
# Dependencies needed to compile OpenTTD
RUN apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends \
    \
    bzip2 \
    ca-certificates \
    cmake \
    git \
    tar \
    wget \
    gnupg2 \
    libc6-dev \
    libfile-fcntllock-perl \
    libfontconfig-dev \
    libicu-dev \
    liblzma-dev \
    liblzo2-dev \
    libsdl1.2-dev \
    libsdl2-dev \
    libxdg-basedir-dev \
    make \
    file \
    software-properties-common \
    xz-utils \
    zlib1g-dev \
    clang
RUN mkdir /build
WORKDIR /build
RUN git clone -b $OPENTTD_RELEASE --depth 1 https://github.com/OpenTTD/OpenTTD.git OpenTTD-$OPENTTD_RELEASE
RUN wget https://cdn.openttd.org/opengfx-releases/$OPENGFX_RELEASE/opengfx-$OPENGFX_RELEASE-all.zip
RUN tar xzf opengfx-$OPENGFX_RELEASE-all.zip
WORKDIR /build/OpenTTD-$OPENTTD_RELEASE
RUN mkdir build
WORKDIR /build/OpenTTD-$OPENTTD_RELEASE/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo -DOPTION_DEDICATED=ON -DCMAKE_INSTALL_PREFIX=/usr ..
RUN make -j $(nproc)
RUN make package

FROM ${DISTRO}:${RELEASE}
ARG OPENTTD_RELEASE=12.0
ARG OPENGFX_RELEASE=7.1
ARG DISTRO
ARG RELEASE
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

COPY --from=builder /build/opengfx-$OPENGFX_RELEASE/* /usr/share/games/openttd/baseset/opengfx/
COPY --from=builder /build/OpenTTD-$OPENTTD_RELEASE/build/bundles/openttd-$OPENTTD_RELEASE-linux-*.deb .
RUN apt-get update
RUN apt-get install -y --no-install-recommends \
    \
    dumb-init \
    libpng16-16 \
    liblzo2-2
# have to use --force-architecture due to aarch64/arm64 issue (deb file is aarch64, but apt/dpkg expects arm64)
RUN dpkg -i --force-architecture ./openttd-$OPENTTD_RELEASE-linux-*.deb
RUN apt-get clean && rm -rf /var/cache/apt/ && rm -rf /var/lib/apt/lists #&& rm -f openttd-$OPENTTD_RELEASE-linux-*.deb
RUN adduser --disabled-password openttd
USER openttd
WORKDIR /home/openttd/.openttd
VOLUME /home/openttd/.openttd
EXPOSE 3979/tcp
EXPOSE 3979/udp

STOPSIGNAL 3
ENTRYPOINT [ "/usr/bin/dumb-init", "--rewrite", "15:3", "--rewrite", "9:3", "--" ]
CMD ["/usr/games/openttd", "-c", "/home/openttd/.openttd/openttd.cfg", "-D", "-x"]
