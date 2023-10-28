FROM ubuntu:23.10 AS build

ARG JANUS_LATEST_TAG

RUN apt-get update && apt-get upgrade -y

RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y \
    libmicrohttpd-dev \
    libjansson-dev \
    libssl-dev \
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
    wget \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    ninja-build && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages meson

RUN git clone https://gitlab.freedesktop.org/libnice/libnice.git && \
    cd libnice && \
    meson --prefix=/usr build && \
    ninja -C build && \
    ninja -C build install

RUN git clone https://github.com/sctplab/usrsctp.git && \
    cd usrsctp && \
    ./bootstrap && \
    ./configure --prefix=/usr --libdir=/usr/lib64 --disable-programs --disable-inet --disable-inet6 && \
    make && make install

RUN git clone https://github.com/warmcat/libwebsockets.git && \
    cd libwebsockets && \
    git checkout v4.3-stable && \
    mkdir build && \
    cd build && \
    cmake -DLWS_MAX_SMP=1 -DLWS_WITHOUT_EXTENSIONS=0 -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" ..  && \
    make &&  make install

RUN wget https://github.com/cisco/libsrtp/archive/v2.5.0.tar.gz && \
    tar xfv v2.5.0.tar.gz && \
    cd libsrtp-2.5.0 && \
    ./configure --prefix=/usr --enable-openssl && \
    make shared_library && make install

RUN  git clone https://github.com/meetecho/janus-gateway.git && \
    cd janus-gateway && \
    git checkout refs/tags/${JANUS_LATEST_TAG} && \
    sh autogen.sh && \
    ./configure --prefix=/usr/local --disable-rabbitmq --disable-mqtt && \
    make && \
    make install && \
    make configs

FROM ubuntu:23.10

RUN useradd -ms /bin/bash samwad

WORKDIR /home/samwad

RUN apt-get -y update && \
    apt-get install -y \
    libmicrohttpd12 \
    libjansson4 \
    libsofia-sip-ua0 \
    libglib2.0-0 \
    libopus0 \
    libogg0 \
    libcurl4 \
    libconfig9 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/lib/libsrtp2.so.1 /usr/lib/libsrtp2.so.1
RUN ln -s /usr/lib/libsrtp2.so.1 /usr/lib/libsrtp2.so

COPY --from=build /usr/lib/x86_64-linux-gnu/libnice.so.10.13.1 /usr/lib/libnice.so.10.13.1
RUN ln -s /usr/lib/libnice.so.10.13.1 /usr/lib/libnice.so.10
RUN ln -s /usr/lib/libnice.so.10.13.1 /usr/lib/libnice.so

COPY --from=build /usr/lib/libsrtp2.so /usr/lib/libsrtp2.so

COPY --from=build /usr/lib/libwebsockets.so.19 /usr/lib/libwebsockets.so.19
RUN ln -s /usr/lib/libwebsockets.so.19 /usr/lib/libwebsockets.so

COPY --from=build /usr/local/bin/janus /usr/local/bin/janus
COPY --from=build /usr/local/bin/janus-cfgconv /usr/local/bin/janus-cfgconv
COPY --from=build /usr/local/etc/janus /usr/local/etc/janus
COPY --from=build /usr/local/lib/janus /usr/local/lib/janus/
COPY --from=build /usr/local/share/janus /usr/local/share/janus

EXPOSE 10000-10200/udp
EXPOSE 8088
EXPOSE 8188

CMD ["/usr/local/bin/janus"]