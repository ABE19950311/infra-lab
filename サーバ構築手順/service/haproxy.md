https://kakakakakku.hatenablog.com/entry/2016/04/29/234506
https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/7/html/load_balancer_administration/ch-haproxy-setup-vsa

■ 前提条件
・OS
[root@da26a232e4f4 /]# cat /etc/redhat-release
CentOS release 6.10 (Final)

■ 事前準備
backendサーバの起動およびhttpd,nginx等のサービスが動いていること


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

2. corosync,pacemakerインストール
```
// haprocy(primary,secondary)
// yum-config-manager を使うために yum-utils をインストールします
# yum install -y yum-utils
// 依存関係解決のためリポジトリを有効化します (powertoolsはCentOS 8の名称のため、CentOS 7ではepelなどを想定)
# yum-config-manager --enable powertools
# yum install -y corosync

// EOLになっているためリポジトリURLを一括でアーカイブURLに置換
# sed -i -e "s/^mirrorlist=/#mirrorlist=/g" /etc/yum.repos.d/CentOS-*.repo
# sed -i -e "s/^#baseurl=/baseurl=/g" /etc/yum.repos.d/CentOS-*.repo
# sed -i -e "s/mirror.centos.org\/centos\/\$releasever/vault.centos.org\/6.10/g" /etc/yum.repos.d/CentOS-*.repo

// yumのキャッシュをクリア
# yum clean all

// packemaker,pcsリポジトリ有効とインストール
# yum install -y pacemaker corosync cman fence-agents-all
```

3. corosync,pacemaker起動
```
// Can't read file /etc/corosync/corosync.conf: No such file or directoryとなるため
// /var/log/cluster/corosync.logでcorosync [MAIN  ] parse error in config: No interfaces definedが出た場合は
// interfaceを追加する
// https://qiita.com/11ohina017/items/dc4f0e9f563699773571
// https://qiita.com/tukiyo3/items/162e131007365fc4fe80
// https://qiita.com/takehironet/items/ee6a50f7f9b349abd085
# vi /etc/corosync/corosync.conf
totem {
    version: 2
    cluster_name: haproxy_cluster
    secauth: off
    transport: udpu

    interface {
        ringnumber: 0
        # クラスタ通信に使用するネットワークアドレスを指定
        # 例: ノードのIPが 192.168.10.xxx の場合、192.168.10.0 を指定
        bindnetaddr: 172.28.0.0

        # マルチキャストポートの設定
        # (多くの場合、デフォルト値のままで動作する)
        mcastport: 5405
        ttl: 1
    }
}

nodelist {
    node {
        ring0_addr: lb1のIP
        nodeid: 1
    }

    node {
        ring0_addr: lb2のIP
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

// サービスの起動と自動起動設定
# service corosync start
# chkconfig corosync on

// corosync起動後に行う
# service pacemaker start
# chkconfig pacemaker on

// pcs構築時のError: Unable to communicateを防ぐため
# service pcsd start
# chkconfig pcsd on
```

4. cluster構築
```
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
```