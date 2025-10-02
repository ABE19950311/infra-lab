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
    dnf install -y nrpe && \
    dnf clean all

# COPY ./nrpe.cfg /etc/nagios/nrpe.cfg
# https://dev.mysql.com/get/mysql80-community-release-el8-1.noarch.rpm && \
#    dnf install -y mysql-server && \

CMD ["mysqld"]