FROM centos:6

# yumリポジトリをEOL後のアーカイブ用に変更
# これをしないとyum installが失敗します
RUN sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/CentOS-Base.repo
RUN sed -i 's/^#baseurl/baseurl/g' /etc/yum.repos.d/CentOS-Base.repo
RUN sed -i 's/^mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-Base.repo

RUN yum install -y epel-release && \
    yum install -y \
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
    yum install -y nrpe && \
    yum clean all

# COPY ./nrpe.cfg /etc/nagios/nrpe.cfg
# https://dev.mysql.com/get/mysql80-community-release-el8-1.noarch.rpm && \
#    yum install -y mysql-server && \