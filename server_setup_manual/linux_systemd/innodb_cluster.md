■ 事前準備

1. dbサーバでmysqlsh用のユーザを作成して権限を付与する
````````````````````````````````````````````````````
// local
$ ssh dbサーバ
// dbサーバ
$ sudo -i or su -
# mysql -u root
> create user 'root'@'%' identified by 'パスワード';
> grant all on *.* to 'root'@'%' with grant option;
> exit
// 残りのdbサーバに対しても同様に実施する
````````````````````````````````````````````````````

■ 作業手順

1. mysqlrouter,corosync,pacemaker導入
````````````````````````````````````````````````````
// mysqlrouterサーバ(primary,secondary)
// MySQL公式リポジトリ追加（AlmaLinux 9用）
# dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm

// MySQLの公式GPGキーを取得
// https://qiita.com/Code_Dejiro/items/c97c400b92a85dce4468
# rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2023

// MySQL Router, mysqlsh のインストール
# dnf install -y mysql-router mysql-shell

// corosync, pacemaker, pcs, fence-agents の一括インストール
// （AlmaLinux 9の HighAvailability リポジトリを指定）
# dnf install -y corosync pcs pacemaker fence-agents-all --enablerepo=highavailability
````````````````````````````````````````````````````

2. pcsd起動
````````````````````````````````````````````````````
// mysqlrouterサーバ(primary,secondary)
# systemctl start pcsd
# systemctl enable pcsd
# systemctl status pcsd
````````````````````````````````````````````````````

3. hosts記載
````````````````````````````````````````````````````
// mysqlrouterサーバ(primary,secondary)
# vi /etc/hosts
172.28.10.4 mysqlrouter_ro
172.28.10.5 mysqlrouter_rw
172.28.10.6 mysqlrouter_ra
172.28.10.7 mysqlrouter_rb
172.28.10.8 db1
172.28.10.9 db2
172.28.10.10 db3 
# ping -c 3 mysqlrouter_ro
# ping -c 3 mysqlrouter_rw
# ping -c 3 mysqlrouter_ra
# ping -c 3 mysqlrouter_rb
# ping -c 3 db1
# ping -c 3 db2
# ping -c 3 db3
````````````````````````````````````````````````````

4. 既にデータが存在していて、クラスタの構成をやり直す場合、メタデータの削除をする。それ以外は以下の手順は実施しない事（クラスタの構成情報が消えるため）
````````````````````````````````````````````````````
// mysqlrouterサーバ(primary,secondaryどちらか)
# mysqlsh
> \c root@プライマリにするいずれかのdbサーバのIP
> dba.dropMetadataSchema()
> \quit
````````````````````````````````````````````````````

5. innodbクラスタ構築
````````````````````````````````````````````````````
mysqlrouterサーバ(primary,secondaryどちらか)
// https://blog.s-style.co.jp/2024/09/2722/
# mysqlsh
// ERROR: Instance must be configured and validated with dba.checkInstanceConfiguration() and dba.configureInstance() before it can be used in an InnoDB cluster.
と出るため、クラスタ作成前にconfigureチェックする
> dba.configureInstance('root@各dbサーバのIP')
Do you want to perform the required configuration changes? [y/n]: y
Do you want to restart the instance after configuring it? [y/n]: y
-> 他ノードに対しても同様に実行する
> \quit

// クラスタ構築
> \c root@プライマリにするいずれかのdbサーバのIP
> cluster = dba.createCluster('innodb_cluster')
> cluster.addInstance('root@上記で指定した他ノードのdbサーバIP')
Please select a recovery method [C]lone/[I]ncremental recovery/[A]bort (default Clone): C
// ステータス確認（全ノードが ONLINE になっていれば成功）
> cluster.status()
> \quit

// ※二回目以降、再度接続してステータスを確認する際のコマンド
# mysqlsh
> \c root@プライマリのIP
> cluster = dba.getCluster()
> cluster.status()
````````````````````````````````````````````````````

6. mysqlrouter設定
````````````````````````````````````````````````````
mysqlrouterサーバ(primary,secondary)
// https://blog.s-style.co.jp/2024/09/2722/
// IPはinnodbクラスタプライマリのIP
# mysqlrouter --bootstrap root@innodbクラスタプライマリのIP --user=mysqlrouter --force
// bootstrap後にmysqlrouterが起動しない場合、権限が不適切。下記ディレクトリ以下の権限修正する
# chown -R mysqlrouter:mysqlrouter /var/lib/mysqlrouter 
# chown -R mysqlrouter:mysqlrouter /etc/mysqlrouter
# chown -R mysqlrouter:mysqlrouter /var/log/mysqlrouter
// bootstrap後の設定修正
# vi /etc/mysqlrouter/mysqlrouter.conf
// 例
# File automatically generated during MySQL Router bootstrap
[DEFAULT]
name=system
keyring_path=/var/lib/mysqlrouter/keyring
master_key_path=/etc/mysqlrouter/mysqlrouter.key
connect_timeout=15
read_timeout=30
dynamic_state=/var/lib/mysqlrouter/state.json

[logger]
level = INFO

[metadata_cache:sps25_aws_set10_innodb_cluster]
router_id=1
user=mysql_router1_uro3cty50t7j
metadata_cluster=sps25_aws_set10_innodb_cluster
ttl=0.5
use_gr_notifications=0

[routing:sps25_aws_set10_innodb_cluster_default_rw]
bind_address=10.201.0.50
bind_port=3306
destinations=metadata-cache://sps25_aws_set10_innodb_cluster/default?role=PRIMARY
routing_strategy=first-available
protocol=classic

[routing:sps25_aws_set10_innodb_cluster_default_ro]
bind_address=10.201.0.51
bind_port=3306
destinations=metadata-cache://sps25_aws_set10_innodb_cluster/default?role=SECONDARY
routing_strategy=round-robin-with-fallback
protocol=classic

// pcs clusterフェールオーバ後に自動起動するように
# systemctl enable mysqlrouter
````````````````````````````````````````````````````

6. pcs cluster構築
````````````````````````````````````````````````````
mysqlrouterサーバ(primary,secondary)
// haltuserパス初期化
# passwd hacluster
// https://docs.redhat.com/ja/documentation/red_hat_enterprise_linux/8/html/considerations_in_adopting_rhel_8/new_commands_for_authenticating_nodes_in_a_cluster
// バージョン違いでコマンド異なる
// primary,secondary両方のmysqlrouterサーバでpasswdコマンド実行しておくこと
# pcs host auth mysqlrouter_ra mysqlrouter_rb
# pcs cluster setup --force create_cluster mysqlrouter_ra mysqlrouter_rb
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
// aws_routerの設定はawscli等別途必要になるため、とりあえずrouter_vipの方だけで良い
// mysqlrouterのプライマリとセカンダリにそれぞれ紐づける仮想IPをつくる
# pcs resource create Router_VIP_RW ocf:heartbeat:IPaddr2 ip=172.28.10.5 cidr_netmask=16 op monitor interval=5s on-fail="standby" --group RG_router
# pcs resource create Router_VIP_RO ocf:heartbeat:IPaddr2 ip=172.28.10.4 cidr_netmask=16 op monitor interval=5s on-fail="standby" --group RG_router
# pcs resource create mysqlrouter systemd:mysqlrouter op monitor interval=5s on-fail="standby" --group RG_router
# pcs resource create AWS_Router_VIP_RW ocf:heartbeat:awsvip secondary_private_ip=172.28.10.5 op monitor interval=5s on-fail="standby" --group RG_router
# pcs resource create AWS_Router_VIP_RO ocf:heartbeat:awsvip secondary_private_ip=172.28.10.4 op monitor interval=5s on-fail="standby" --group RG_router
# pcs constraint colocation add Router_VIP_RW with mysqlrouter score=INFINITY
# pcs constraint colocation add Router_VIP_RO with mysqlrouter score=INFINITY
# pcs constraint colocation add AWS_Router_VIP_RW with mysqlrouter score=INFINITY
# pcs constraint colocation add AWS_Router_VIP_RO with mysqlrouter score=INFINITY
# pcs status
// フェールオーバー検証
# pcs node standby mysqlrouter_ra
# pcs status 
⇒Started mysqlrouter_rbになっていること
⇒rbでmysqlrouteがactiveになっていること
# pcs node unstandby mysqlrouter_ra
# pcs node standby mysqlrouter_rb
# pcs status 
⇒Started mysqlrouter_raになっていること
⇒raでmysqlrouteがactiveになっていること
# pcs node unstandby mysqlrouter_rb
// mysql疎通確認
// activeサーバの方に設定した仮想IPが付与される
[root@4bad3b57decd /]# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0@if41: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether 22:65:4f:df:ce:fd brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.28.10.6/16 brd 172.28.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 172.28.10.5/16 brd 172.28.255.255 scope global secondary eth0
       valid_lft forever preferred_lft forever
    inet 172.28.10.4/16 brd 172.28.255.255 scope global secondary eth0
       valid_lft forever preferred_lft forever
# mysql -u root -h 172.28.10.5 -P 6446
# mysql -u root -h 172.28.10.4 -P 6447
````````````````````````````````````````````````````
※aws /etc/hostsに書いてあった、
10.201.1.30 aws_spdb14rw
10.201.1.31 aws_spdb14ro
は、pcs cluster構築時に作成する仮想IPであって、実体（ec2）は存在していない
そのため、上記に該当するサーバの実体は作らなくて良い