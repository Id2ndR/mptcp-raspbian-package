FROM debian
MAINTAINER Id2ndR <none>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
                cpio \
                ca-certificates \
                wget \
                tar \
                libncurses-dev \
                build-essential \
                fakeroot ccache \
#               kernel-package \
                u-boot-tools \
                zlib1g-dev \
                libncurses5-dev \
                liblz4-tool \
                git bc \
                debhelper quilt \
                kmod \
                rsync \
        && rm -rf /var/lib/apt/lists/*

# https://www.raspberrypi.org/documentation/linux/kernel/building.md

COPY build-kernel.sh config-enable-mptcp.patch ./
#RUN bash -e build-kernel.sh

COPY build-package.sh ./
#RUN bash -e build-package.sh

CMD sleep infinity
