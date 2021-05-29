FROM ubuntu:18.04

USER root

# install neccessary libs/packages for 3df pcasl binary
RUN dpkg --add-architecture i386
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
           wget \
           multiarch-support \
           libfreetype6:i386 \
           libsm6:i386 \
           libice6:i386 \
           libxrender1:i386 \
           libfontconfig1:i386 \
           libxext6:i386 \
           libx11-6:i386 \
           libmotif-dev \
           libxm4:i386 \
           libmrm4:i386 \
           libxm4 \
           libuil4 \
           libxpm4:i386 \
    && wget http://ftp.us.debian.org/debian/pool/main/libx/libxp/libxp6_1.0.2-2_i386.deb \
    && dpkg -i ./libxp6_1.0.2-2_i386.deb

CMD ["/bin/bash"]