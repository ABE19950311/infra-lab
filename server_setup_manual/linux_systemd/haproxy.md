https://kakakakakku.hatenablog.com/entry/2016/04/29/234506
https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/7/html/load_balancer_administration/ch-haproxy-setup-vsa


■ 事前準備
backendサーバの起動およびhttpd,nginx等のサービスが動いていること


■ 作業手順

1. host名変更
```````````````````````````````
// lb
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

2. haproxyインストール
```````````````````````````````
# dnf install -y haproxy
# systemctl start haproxy
# systemctl enable haproxy
# systemctl status haproxy
```````````````````````````````

3. haproxy.cfg編集
```````````````````````````````
# vi /etc/haproxy/haproxy.cfg
// mainという名前でlb定義
frontend main
    bind *:80
    //記載した条件（静的ファイル）なら、staticという名前のbackendに送る
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    //上記条件に一致しないデフォルトのリクエストはbackend appに送る
    default_backend             app

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
```````````````````````````````

4. haproxy再起動
```````````````````````````````
# systemctl restart haproxy
# systemctl status haproxy
```````````````````````````````

5. firewall,selinuxが無効になっている事を確認
```````````````````````````````
# systemctl status firewalld
⇒起動してたら、stopとdisable
# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
```````````````````````````````

■ https化

1. ssl証明書を用意する

2. haproxy.cfg設定追記
```````````````````````````````
frontend main
    bind *:80
    // 追記
    bind *:443 ssl crt /root/server.pem
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    default_backend             app
```````````````````````````````

3. haproxy再起動
```````````````````````````````
# systemctl restart haproxy
# systemctl status haproxy
```````````````````````````````

■ haporxyクラスタ化

1. hosts記載
````````````````````````````````````````````````````
# vi /etc/hosts
--------------追記----------------
lb1IP haproxy1
lb2IP haproxy2
````````````````````````````````````````````````````

2. corosync,pacemakerインストール
````````````````````````````````````````````````````
// haprocy(primary,secondary)
// corosyncの依存関係解決後インストール
# dnf install -y dnf-plugins-core
# dnf config-manager --set-enabled ha
// packemaker,pcsリポジトリ有効とインストール
// https://qiita.com/n-kashimoto/items/b22c35631bef26367897
# dnf install -y corosync pcs pacemaker fence-agents-all
````````````````````````````````````````````````````

3. corosync,pacemaker起動
````````````````````````````````````````````````````
！！！手動でcorosync.confを作成する必要はあるのか？
！！！pcs cluster setup ～で自動作成されないか、再検証が必要
https://clusterlabs.org/projects/pacemaker/doc/deprecated/en-US/Pacemaker/2.0/html/Pacemaker_Remote/_configure_corosync_on_cluster_nodes.html
！！！pacemaker,corosyncをここで起動する必要はあるのか？
！！！クラスタ起動時に自動で有効にならないか？pcsdだけで良いのでは
https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/8/html/configuring_and_managing_high_availability_clusters/assembly_getting-started-with-pacemaker-configuring-and-managing-high-availability-clusters

// Can't read file /etc/corosync/corosync.conf: No such file or directoryとなるため
# vi /etc/corosync/corosync.conf
totem {
    version: 2
    cluster_name: haproxy_cluster
    secauth: off
    transport: udpu
}

nodelist {
    node {
        ring0_addr: haproxy1
        nodeid: 1
    }

    node {
        ring0_addr: haproxy2
        nodeid: 2
    }
}

quorum {
    provider: corosync_votequorum
    two_node: 1
}

logging {
    to_logfile: yes
    logfile: /var/log/cluster/corosync.log
    to_syslog: yes
}

# systemctl start corosync
// corosync起動後に行う
# systemctl start pacemaker
// pcs構築時のError: Unable to communicateを防ぐため
# systemctl start pcsd
````````````````````````````````````````````````````

4. cluster構築
````````````````````````````````````````````````````
// haproxy(primary,secondary)
// haltuserパス初期化
# passwd hacluster
// https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/8/html/considerations_in_adopting_rhel_8/new_commands_for_authenticating_nodes_in_a_cluster
// バージョン違いでコマンド異なる
// primary,secondary両方のhaproxyサーバでpasswdコマンド実行しておくこと
# pcs host auth haproxy1 haproxy2
# pcs cluster setup --force haproxy_cluster haproxy1 haproxy2
// pcsクラスター起動
// https://www.server-world.info/query?os=CentOS_Stream_9&p=pacemaker&f=1
# pcs cluster start --all
# pcs cluster status
// pcs各設定
// https://qiita.com/n-kashimoto/items/b22c35631bef26367897
// 以下の設定は検証用としてstonith,quorumの設定を無効化しているため
// 本番環境では十分検討してから行うこと
# pcs property set stonith-enabled=false
# pcs property set no-quorum-policy=ignore
// 仮想VIPおよびフェールオーバー設定
# pcs resource create Router_VIP ocf:heartbeat:IPaddr2 ip=172.28.10.250 cidr_netmask=16 op monitor interval=5s on-fail="standby" --group RG_router
# pcs resource create haproxy systemd:haproxy op monitor interval=5s on-fail="standby" --group RG_router
# pcs constraint colocation add Router_VIP with haproxy score=INFINITY
# pcs status
````````````````````````````````````````````````````