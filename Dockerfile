FROM base/devel
MAINTAINER phillip@schichtel

COPY pacman.conf /etc/pacman.conf
RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm archlinux-keyring && \
    pacman -Su --noconfirm

RUN yes | pacman -S gcc-multilib
RUN pacman -S --noconfirm repose devtools

RUN useradd --home /build --create-home builder
WORKDIR /build
COPY sudoer.conf /etc/sudoers.d/builder

ENV REPO=cubyte \
    UTILS=aurutils-git

RUN mkdir /repo && chown builder:builder /repo
VOLUME ["/repo"]

USER builder

RUN curl -O https://aur.archlinux.org/cgit/aur.git/snapshot/${UTILS}.tar.gz && \
    tar xf ${UTILS}.tar.gz && \
    cd ${UTILS} && \
    makepkg --syncdeps --clean --noconfirm && \
    sudo pacman -U --noconfirm ${UTILS}-*.pkg.tar.xz && \
    cd .. && \
    rm -Rf ${UTILS} ${UTILS}.tar.gz && \
    yes | sudo pacman -Sccc

COPY build.sh /build/build.sh

ENTRYPOINT ["/build/build.sh"]

