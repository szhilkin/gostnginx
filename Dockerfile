FROM stackbrew/ubuntu:14.04
MAINTAINER Sergey Zhilkin <szhilkin@gmail.com>

ENV DEBIAN_FRONTEND noninteractive
RUN locale-gen en_US.UTF-8 && dpkg-reconfigure locales
RUN sed -i s/main/'main universe'/ /etc/apt/sources.list
RUN echo udev hold | dpkg --set-selections && \
    echo initscripts hold | dpkg --set-selections &&\
    echo upstart hold | dpkg --set-selections &&\
    apt-get update -q &&\
    apt-get -y upgrade

RUN apt-get -y install wget git unzip build-essential

ENV NGINX_VERSION 1.9.9
ENV PCRE_VERSION 8.38
ENV ZLIB_VERSION 1.2.8
ENV LIBRESSL_VERSION 1.0.1h

WORKDIR /usr/src

RUN wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-${PCRE_VERSION}.tar.gz &&\
    tar -xf pcre-${PCRE_VERSION}.tar.gz &&\
    rm -f pcre-${PCRE_VERSION}.tar.gz

RUN wget http://zlib.net/zlib-${ZLIB_VERSION}.tar.gz &&\
    tar -xf zlib-${ZLIB_VERSION}.tar.gz &&\
    rm -f zlib-${ZLIB_VERSION}.tar.gz

RUN wget http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz &&\
    tar -xf libressl-${OPENSSL_VERSION}.tar.gz &&\
    rm -f libressl-${OPENSSL_VERSION}.tar.gz

RUN wget http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz &&\
    tar -xf nginx-${NGINX_VERSION}.tar.gz &&\
    rm -f nginx-${NGINX_VERSION}.tar.gz

# Modules

# Configure nginx

RUN cd /usr/src/nginx-${NGINX_VERSION} && ./configure \
    --prefix=/opt/nginx \
    --user=nobody \
    --group=nogroup \
    --conf-path=/etc/nginx/nginx.conf \
    --error-log-path=/var/log/nginx/error.log \
    --sbin-path=/usr/sbin/nginx \
    --http-client-body-temp-path=/var/lib/nginx/body \
    --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
    --http-log-path=/var/log/nginx/access.log \
    --http-proxy-temp-path=/var/lib/nginx/proxy \
    --http-scgi-temp-path=/var/lib/nginx/scgi \
    --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
    --lock-path=/var/lock/nginx.lock \
    --pid-path=/var/run/nginx.pid \
    --with-http_addition_module \
    --with-http_secure_link_module \
    --with-http_dav_module \
    --with-http_gzip_static_module \
    --with-http_realip_module \
    --with-http_stub_status_module \
    --with-http_ssl_module \
    --with-http_spdy_module \
    --with-http_sub_module \
    --with-ipv6 \
    --without-mail_pop3_module \
    --without-mail_imap_module \
    --without-mail_smtp_module \
    --with-openssl=/usr/src/libressl-${LIBRESSL_VERSION} \
#    --with-openssl-opt="enable-ec_nistp_64_gcc_128 no-krb5 enable-tlsext" \
    --with-pcre=/usr/src/pcre-${PCRE_VERSION} \
    --with-pcre-jit \
    --with-zlib=/usr/src/zlib-${ZLIB_VERSION} \
   mkdir -p /var/lib/nginx &&\
   mkdir -p /www

RUN mkdir /rootfs
RUN cd /usr/src/nginx-${NGINX_VERSION} && make && make DESTDIR=/rootfs install

RUN apt-get install -qy busybox-static

# Build Root FS for nano image creation
WORKDIR /rootfs
RUN mkdir -p bin etc dev dev/pts lib proc sys tmp usr
RUN touch etc/resolv.conf
RUN cp /etc/nsswitch.conf etc/nsswitch.conf
RUN echo root:x:0:0:root:/:/bin/sh > etc/passwd
RUN echo root:x:0: > etc/group
RUN fgrep nobody /etc/passwd >> etc/passwd
RUN fgrep nogroup /etc/group >> etc/group
RUN ln -s lib lib64
RUN ln -s usr/lib lib64
RUN ln -s bin sbin
RUN cp /bin/busybox bin
RUN for X in $(busybox --list) ; do ln -s busybox bin/$X ; done
RUN bash -c "cp /lib/x86_64-linux-gnu/lib{c,dl,nsl,nss_*,pthread,resolv,crypt,rt,m,gcc_s}.so.* lib"
RUN bash -c "cp /usr/lib/x86_64-linux-gnu/libstdc++.so.* lib"
RUN cp /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 lib
ADD nginx /rootfs/etc/nginx
RUN bash -c "mkdir -p /rootfs/var/lib/nginx/{body,fastcgi,proxy,scgi,uwsgi}"
RUN mkdir /rootfs/www && bash -c "mkdir -p /rootfs/www/{empty,default}" && mv /rootfs/opt/nginx/html/* /rootfs/www/default && rm -Rf /rootfs/opt/nginx && chown -R nobody:nogroup /rootfs/www
RUN tar cf /rootfs.tar .
RUN for X in console null ptmx random stdin stdout stderr tty urandom zero ; do tar uf /rootfs.tar -C/ ./dev/$X ; done
