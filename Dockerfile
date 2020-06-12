FROM ubuntu:20.04 AS build

RUN apt-get update && apt-get upgrade -y

RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y \
    libmicrohttpd-dev \
    libjansson-dev \
    libssl-dev \
    libsrtp2-dev \
    libsofia-sip-ua-dev \
    libglib2.0-dev \
    libopus-dev \
    libogg-dev \
    libcurl4-openssl-dev \
    liblua5.3-dev \
    libconfig-dev \
    pkg-config \
    gengetopt \
    libtool \
    automake \
    cmake \
    git \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel ninja-build && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install meson

RUN git clone https://gitlab.freedesktop.org/libnice/libnice.git && \
    cd libnice && \
    meson --prefix=/usr build && \
    ninja -C build && \
    ninja -C build install

RUN git clone https://github.com/sctplab/usrsctp.git && \
    cd usrsctp && \
    ./bootstrap && \
    ./configure --prefix=/usr && make && make install

RUN git clone https://github.com/warmcat/libwebsockets.git && \
    cd libwebsockets && \
    git checkout v3.2-stable && \
    mkdir build && \
    cd build && \
    cmake -DLWS_MAX_SMP=1 -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" ..  && \
    make &&  make install

RUN  git clone https://github.com/meetecho/janus-gateway.git && \
    cd janus-gateway && \
    git checkout refs/tags/v0.10.1 && \
    sh autogen.sh && \
    ./configure --prefix=/usr/local && \
    make && \
    make install && \
    make configs

FROM ubuntu:20.04 

RUN useradd -ms /bin/bash samwad

WORKDIR /home/samwad

RUN apt-get -y update && \
    apt-get install -y \
    libmicrohttpd12 \
    libjansson4 \
    libsrtp2-1 \
    libsofia-sip-ua0 \
    libglib2.0-0 \
    libopus0 \
    libogg0 \
    libcurl4 \
    libconfig9 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/lib/x86_64-linux-gnu/libnice.so.10.10.0 /usr/lib/libnice.so.10.10.0
RUN ln -s /usr/lib/libnice.so.10.10.0 /usr/lib/libnice.so.10
RUN ln -s /usr/lib/libnice.so.10.10.0 /usr/lib/libnice.so

COPY --from=build /usr/lib/libusrsctp.so.1.0.0 /usr/lib/libusrsctp.so.1.0.0
RUN ln -s /usr/lib/libusrsctp.so.1.0.0 /usr/lib/libusrsctp.so
RUN ln -s /usr/lib/libusrsctp.so.1.0.0 /usr/lib/libusrsctp.so.1

COPY --from=build /usr/lib/libwebsockets.so.15 /usr/lib/libwebsockets.so.15
RUN ln -s /usr/lib/libwebsockets.so.15 /usr/lib/libwebsockets.so

COPY --from=build /usr/local/bin/janus /usr/local/bin/janus
COPY --from=build /usr/local/bin/janus-cfgconv /usr/local/bin/janus-cfgconv
COPY --from=build /usr/local/etc/janus /usr/local/etc/janus
COPY --from=build /usr/local/lib/janus /usr/local/lib/janus/
COPY --from=build /usr/local/share/janus /usr/local/share/janus

EXPOSE 10000-10200/udp
EXPOSE 8088
EXPOSE 8188

CMD ["/usr/local/bin/janus"]