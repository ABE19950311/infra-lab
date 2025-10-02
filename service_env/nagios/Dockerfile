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
    yum clean all

# デフォルトの設定やユーザ設定を行う（必要に応じて）
# httpd \yum install -y httpd nagios nagios-plugins nagios-plugins-nrpe && \
