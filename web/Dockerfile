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

# COPY ./nrpe.cfg /etc/nagios/nrpe.cfg
# httpd \

CMD ["/usr/sbin/httpd", "-DFOREGROUND"]