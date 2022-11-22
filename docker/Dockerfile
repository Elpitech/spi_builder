FROM debian:bullseye-slim
MAINTAINER Nick Zhuravlev <nikolay.zhuravlev@elpitech.ru>

# RUN echo 'Acquire::http::Proxy "http://user:pass@proxy30.tp-local.ru:3128";' > /etc/apt/apt.conf.d/1-proxy
RUN apt-get update \
    && apt-get -y -q install \
        crossbuild-essential-mipsel build-essential git fakeroot \
        libncurses-dev libssl-dev libelf-dev bison flex vim device-tree-compiler \
        sloccount cppcheck gcc-arm-none-eabi python gcc-aarch64-linux-gnu \
        qemu-user-static debootstrap sudo crossbuild-essential-arm64 \
        nasm iasl python3-distutils texinfo subversion imagemagick xxd librsvg2-bin \
		uuid-dev libgmp3-dev libmpfr-dev libarchive-zip-perl curl \
    && apt-get clean

# Not sure why en_US is missing, create it
RUN apt-get -y -q install locales \
	&& localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8
ENV LANG en_US.utf8

ARG uid
RUN useradd -u $uid -ms /bin/bash builder && \
		mkdir /home/builder/workspace
RUN echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

### USER ###
USER builder
WORKDIR /home/builder/workspace
