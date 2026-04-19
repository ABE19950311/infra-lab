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
// ノード全台落とした後等で、以下のメッセージが発生する場合は、いずれかのノードで
// dba.rebootClusterFromCompleteOutage() を実行する
Dba.getCluster: This function is not available through a session to a standalone instance (metadata exists, instance belongs to that metadata, but GR is not active) (MYSQLSH 51314)
````````````````````````````````````````````````````

6. mysqlrouter設定
````````````````````````````````````````````````````
// mysqlrouterサーバ(primary,secondary) 両方で実施

// bootstrapの実行（IPはinnodbクラスタのPRIMARYのIPを指定）
# mysqlrouter --bootstrap root@primaryIP --user=mysqlrouter --force

// 権限修正
# chown -R mysqlrouter:mysqlrouter /var/lib/mysqlrouter
# chown -R mysqlrouter:mysqlrouter /etc/mysqlrouter
# chown -R mysqlrouter:mysqlrouter /var/log/mysqlrouter

// bootstrap後の設定確認（※手動での書き換えは不要です！）
# cat /etc/mysqlrouter/mysqlrouter.conf
// --- 確認ポイント ---
// [routing:innodb_cluster_default_rw] の bind_port が 6446
// [routing:innodb_cluster_default_ro] の bind_port が 6447
// になっていればOKです。（bind_address は 0.0.0.0 のままで問題ありません）

//　【重要】OSでの自動起動を無効化（Pacemakerに管理させるため）
# systemctl disable mysqlrouter
# systemctl stop mysqlrouter
````````````````````````````````````````````````````

7. pcs cluster構築
````````````````````````````````````````````````````
// mysqlrouterサーバ(primary,secondary) 両方で実施

// haclusterユーザーのパスワード初期化
# passwd hacluster

// クラスターの認証と作成（※以降はどちらか1台で実行すればOK）
# pcs host auth mysqlrouterPrimary mysqlrouterSecondary
Username : hacluster
// エラーが発生する場合はpcsdが起動している事とfirewalを確認
# firewall-cmd --add-service=high-availability --permanent
# firewall-cmd --reload

# pcs cluster setup create_cluster mysqlrouterPrimary mysqlrouterSecondary

// pcsクラスター起動
# pcs cluster start --all
# pcs cluster status

// pcs各設定（※検証環境用）
# pcs property set stonith-enabled=false
# pcs property set no-quorum-policy=ignore

// 仮想VIPおよびフェールオーバー設定
// ※グループ（RG_router）を指定して順に登録することで、自動的に同じノードで連動して起動します
# pcs resource create Router_VIP_RW ocf:heartbeat:IPaddr2 ip=primaryVIP cidr_netmask=16 op monitor interval=5s on-fail="standby" --group RG_router
# pcs resource create Router_VIP_RO ocf:heartbeat:IPaddr2 ip=secondaryVIP cidr_netmask=16 op monitor interval=5s on-fail="standby" --group RG_router
# pcs resource create mysqlrouter systemd:mysqlrouter op monitor interval=5s on-fail="standby" --group RG_router

// ※AWS用のVIP設定はAWS環境構築時に実施するため今回はスキップ
// # pcs resource create AWS_Router_VIP_RW ocf:heartbeat:awsvip ...
// # pcs resource create AWS_Router_VIP_RO ocf:heartbeat:awsvip ...

# pcs cluster enable --all
# pcs status
//   * Router_VIP_RW start on alma9-mysqlra returned 'not installed' ([findif] failed) at Sat Apr 18 22:50:14 2026 after 244ms のようなエラーが出る場合は以下を実施する
# pcs resource update Router_VIP_RW nic="VIP付与nic名"
# pcs resource update Router_VIP_RO nic="VIP付与nic名"
// エラーが残る場合
# pcs resource cleanup 

// ------------------------------------
// フェールオーバー検証
// ------------------------------------
// raを強制的にスタンバイ状態（疑似障害）にする
# pcs node standby mysqlrouter_ra
# pcs status 
⇒ Started mysqlrouter_rb になっていること
⇒ rbでmysqlrouterがactive(起動)になっていること

// raを復旧させ、次はrbをスタンバイ状態にする
# pcs node unstandby mysqlrouter_ra
# pcs node standby mysqlrouter_rb
# pcs status 
⇒ Started mysqlrouter_ra になっていること
⇒ raでmysqlrouterがactiveになっていること

// rbを復旧させる
# pcs node unstandby mysqlrouter_rb

// ------------------------------------
// mysql疎通確認
// ------------------------------------
// activeサーバの方に設定した仮想IPが付与されているか確認
# ip a

// クライアント（またはルーター自身）から仮想IP経由でDBへ接続確認
# mysql -u root -p -h primaryVIP -P 6446
# mysql -u root -p -h secondaryVIP -P 6447
````````````````````````````````````````````````````
※aws /etc/hostsに書いてあった、
10.201.1.30 aws_spdb14rw
10.201.1.31 aws_spdb14ro
は、pcs cluster構築時に作成する仮想IPであって、実体（ec2）は存在していない
そのため、上記に該当するサーバの実体は作らなくて良い