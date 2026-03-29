https://kakakakakku.hatenablog.com/entry/2016/04/29/234506
https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/7/html/load_balancer_administration/ch-haproxy-setup-vsa

■ 前提条件
・OS
[root@cent6-lb1 ~]# cat /etc/redhat-release
CentOS release 6.10 (Final)

■ 事前準備
backendサーバの起動およびhttpd,nginx等のサービスが動いていること
・リポジトリを変更していること。参照(http://extstrg.asabiya.net/pukiwiki/index.php?CentOS+6+%A5%B5%A5%DD%A1%BC%A5%C8%BD%AA%CE%BB%B8%E5%A4%CE%A5%EA%A5%DD%A5%B8%A5%C8%A5%EA%CA%D1%B9%B9)
crmコマンドはpacemaker1.18以降には含まれない（https://straypenguin.winfield-net.com/ultramonkeyl7.html）
そのため、リポジトリ先をpacemaker1.17が含まれるものに変更して無理やり取得する
```
cp -p /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo_bak
vi /etc/yum.repos.d/CentOS-Base.repo
[base]
name=CentOS-$releasever - Base
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=os
baseurl=http://ftp.riken.jp/Linux/centos-vault/6.3/os/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

#released updates
[updates]
name=CentOS-$releasever - Updates
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=updates
baseurl=http://ftp.riken.jp/Linux/centos-vault/6.3/updates/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=extras
baseurl=http://ftp.riken.jp/Linux/centos-vault/6.3/extras/$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=centosplus
baseurl=http://ftp.riken.jp/Linux/centos-vault/6.3/centosplus/$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

#contrib - packages by Centos Users
[contrib]
name=CentOS-$releasever - Contrib
#mirrorlist=http://mirrorlist.centos.org/?release=$releasever&arch=$basearch&repo=contrib
baseurl=http://ftp.riken.jp/Linux/centos-vault/6.3/contrib/$basearch/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

yum clean all
```


■ 作業手順

1. ホスト名変更
```
// hostnamectlがないため直接編集
# vi /etc/sysconfig/network
---------以下を編集-------
HOSTNAME=ホスト名
# service network restart
```

2. haproxyインストール
```
# yum install -y haproxy
# service haproxy start
# chkconfig haproxy on
# service haproxy status
```

3. haproxy.cfg編集
```
# vi /etc/haproxy/haproxy.cfg
// mainという名前でlb定義
frontend main
    bind *:80
    //記載した条件（静的ファイル）なら、staticという名前のbackendに送る
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    //上記条件に一致しないデフォルトのリクエストはbackend appに送る
    default_backend            app

#---------------------------------------------------------------------
# static backend for serving up images, stylesheets and such
#---------------------------------------------------------------------
backend static
    balance     roundrobin
    server      static 127.0.0.1:4331 check

#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend app
    balance     roundrobin
    //分散先サーバIPとport
    server  app1 172.28.10.3:80 check
    server  app2 172.28.10.4:80 check
```

4. haproxy再起動
```
# service haproxy restart
# service haproxy status
```

5. firewall, selinuxが無効になっている事を確認
```
# service iptables status
⇒起動してたら、stopとdisable
# service iptables stop
# chkconfig iptables off

# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
```


■ https化
1. ssl証明書を用意する

2. haproxy.cfg設定追記
```
frontend main
    bind *:80
    // 追記
    bind *:443 ssl crt /root/server.pem
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    default_backend            app
```

3. haproxy再起動
```
# service haproxy restart
# service haproxy status
```


■ haporxyクラスタ化
https://blog.cetre.co.uk/creating-a-two-node-centos-6-cluster-with-floating-ip-using-cman-and-pacemaker/
https://infra.blog.shinobi.jp/Entry/120/
https://techfacilities.blogspot.com/2014/04/pacemaker-cman.html
https://bbs.archlinux.org/viewtopic.php?id=128061

1. hosts記載
````````````````````````````````````````````````````
# vi /etc/hosts
--------------追記----------------
lb1IP haproxy1
lb2IP haproxy2
````````````````````````````````````````````````````

2. corosync,cman,pacemakerインストール
```
// haprocy(primary,secondary)
# yum install -y corosync pacemaker cman
```

3. cman cluster.conf作成
```
# ccs -f /etc/cluster/cluster.conf --createcluster haproxy_cluster
# ccs -f /etc/cluster/cluster.conf --addnode haproxy1
# ccs -f /etc/cluster/cluster.conf --addnode haproxy2
# ccs -f /etc/cluster/cluster.conf --addfencedev pcmk agent=fence_pcmk
# ccs -f /etc/cluster/cluster.conf --addmethod pcmk-redirect haproxy1
# ccs -f /etc/cluster/cluster.conf --addmethod pcmk-redirect haproxy2
# ccs -f /etc/cluster/cluster.conf --addfenceinst pcmk haproxy1 pcmk-redirect port=haproxy1
# ccs -f /etc/cluster/cluster.conf --addfenceinst pcmk haproxy2 pcmk-redirect port=haproxy2
# echo "CMAN_QUORUM_TIMEOUT=0" >> /etc/sysconfig/cman
```

4. cman,pacemaker起動
```
# service cman start
# service pacemaker start
# chkconfig cman on
# chkconfig pacemaker on
# chkconfig corosync off
# crm_mon -1
```

5. cluster構築
```
// haproxy(どちらか片方)
// 以下の設定は検証用としてstonith,quorumの設定を無効化しているため
// 本番環境では十分検討してから行うこと
# crm configure property no-quorum-policy=ignore
# crm configure property stonith-enabled=false

# crm configure primitive VirtualIP ocf:heartbeat:IPaddr2 params ip=仮想IP cidr_netmask=24 op monitor interval=10s
# crm configure primitive HAProxy lsb:haproxy op monitor interval=10s
# crm configure group RG_router VirtualIP HAProxy
# crm_mon -r1
```




