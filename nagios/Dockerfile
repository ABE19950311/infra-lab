FROM almalinux:8.10-20240723

RUN dnf install -y epel-release && \
    dnf install -y \
        nrpe \
        iproute \
        iputils \
        net-tools \
        procps-ng \
        util-linux \
        curl \
        vim \
        less \
        which \
        sudo \
        bind-utils \
        bash-completion && \
    dnf clean all

# デフォルトの設定やユーザ設定を行う（必要に応じて）
# httpd \dnf install -y httpd nagios nagios-plugins nagios-plugins-nrpe && \

CMD ["/usr/sbin/httpd", "-DFOREGROUND"]