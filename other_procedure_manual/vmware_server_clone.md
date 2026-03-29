### spbcgi0904,spgcgi0904 構築手順書


#### ■ 背景

set9のcgiサーバを追加するため、vmwareで構築作業を行う。


#### ■ 作業対象ホスト

・クローン元
spbcgi0901,spgcgi0901

・構築
spbcgi0904,spgcgi0904


#### ■ 事前作業

spbcgi0904,spgcgi0904構築で使用するIPアドレスが未使用な事を確認する。

いずれの結果も100% packet lossになる事を確認する。

``````````````````````````````
//shcc2
$ ping -c 8 10.200.142.72
$ ping -c 8 10.200.142.132
$ ping -c 8 10.60.142.72
$ ping -c 8 10.60.142.132
``````````````````````````````


#### ■ spbcgi0904 構築手順

1. 下記URLからvmwareにログインする。
https://shvcenter65.adi.estore.co.jp

2. spbcgi0901をクローンする
shvcenter65.adi.estore.co.jp -> Shinkawa DC -> Production -> spbcgi0901 -> アクション -> クローン作成
-> 仮想マシンにクローンを作成 をクリックする。

下記設定でクローンを作成する
・名前とフォルダの選択
　仮想マシン名：spbcgi0904
　フォルダの場所：shvcenter65.adi.estore.co.jp -> Shinkawa DC
・コンピューティング リソースの選択
　Shinkawa DC -> Production -> esxstd33
・ストレージの選択
　ディスクごとに設定：オフ
　仮想ディスク フォーマットの選択：ソースと同じフォーマット
　仮想マシン ストレージ ポリシー：既存の仮想マシン ストレージ ポリシーを保持
　ストレージ：esxstd33_intelP4600_4T
・クローン オプションの設定
　オペレーティング システムのカスタマイズ：オフ
　この仮想マシンのハードウェアをカスタマイズします：オン
　作成後に仮想マシンをパワーオン：オフ
・ハードウェアのカスタマイズ
　仮想ハードウェアから、Network adapter1と2の パワーオン時に接続 をオフにする
・設定の確認
　設定内容に問題がない事を確認して FINISH をクリックする

3. spbcgi0904 の初期設定
shvcenter65.adi.estore.co.jp -> Shinkawa DC -> Production -> spbcgi0904 -> アクション -> 電源 -> パワーオン をクリックし、Webコンソールを起動する。root/21世代からrootになる。

・IPアドレス変更
``````````````````````````````
// spbcgi0904
$ su -
# nmcli c mod ens160 ipv4.addresses 10.60.142.72/16
# cat /etc/sysconfig/network-scripts/ifcfg-ens160
# nmcli c mod ens192 ipv4.addresses 10.200.142.72/16
# cat /etc/sysconfig/network-scripts/ifcfg-ens192
# systemctl restart NetworkManager
# systemctl restart network

// 変更後のIPに対して疎通確認をする
# ping -c 8 10.60.142.72
# ping -c 8 10.200.142.72
``````````````````````````````
・ホスト名変更
``````````````````````````````
// spbcgi0904
# cat /etc/hostname
# hostnamectl set-hostname spbcgi0904
# cat /etc/hostname
``````````````````````````````
・cron,apache停止
``````````````````````````````
// spbcgi0904
# systemctl stop crond
# systemctl status crond
# systemctl stop httpd
# systemctl status httpd
``````````````````````````````
・ログ削除
下記ディレクトリ配下のログを削除する(rotateしているログ)
``````````````````````````````
/var/log
/var/log/httpd
/var/log/mysqlrouter
/var/log/applog
``````````````````````````````
・シャットダウン
``````````````````````````````
// spbcgi0904
# shutdown now
``````````````````````````````

shvcenter65.adi.estore.co.jp -> Shinkawaa DC -> Production -> spbcgi0904 -> アクション -> 設定の編集 から、Network adapter1と2の パワーオン時に接続 をオンにする。
設定編集後、アクション -> 電源 からパワーオンにする。

・shcc2から疎通確認
``````````````````````````````
// shcc2
$ ping -c 8 10.60.142.72
$ ssh p-abe@10.200.142.72
``````````````````````````````
・cron,apache起動確認
``````````````````````````````
// spbcgi0904
# systemctl status crond
# systemctl status httpd
``````````````````````````````


#### ■ spgcgi0904 構築手順

1. spgcgi0901をクローンする
shvcenter65.adi.estore.co.jp -> Shinkawa DC -> Production -> spgcgi0901 -> アクション -> クローン作成
-> 仮想マシンにクローンを作成 をクリックする。

下記設定でクローンを作成する
・名前とフォルダの選択
　仮想マシン名：spgcgi0904
　フォルダの場所：shvcenter65.adi.estore.co.jp -> Shinkawa DC
・コンピューティング リソースの選択
　Shinkawa DC -> Production -> esxstd33
・ストレージの選択
　ディスクごとに設定：オフ
　仮想ディスク フォーマットの選択：ソースと同じフォーマット
　仮想マシン ストレージ ポリシー：既存の仮想マシン ストレージ ポリシーを保持
　ストレージ：esxstd33_intelP4600_4T
・クローン オプションの設定
　オペレーティング システムのカスタマイズ：オフ
　この仮想マシンのハードウェアをカスタマイズします：オン
　作成後に仮想マシンをパワーオン：オフ
・ハードウェアのカスタマイズ
　仮想ハードウェアから、Network adapter1と2の パワーオン時に接続 をオフにする
・設定の確認
　設定内容に問題がない事を確認して FINISH をクリックする

2. spgcgi0904 の初期設定
shvcenter65.adi.estore.co.jp -> Shinkawa DC -> Production -> spgcgi0904 -> アクション -> 電源 -> パワーオン をクリックし、Webコンソールを起動する。root/21世代からrootになる。

・IPアドレス変更
``````````````````````````````
// spgcgi0904
$ su -
# nmcli c mod ens160 ipv4.addresses 10.60.142.132/16
# cat /etc/sysconfig/network-scripts/ifcfg-ens160
# nmcli c mod ens192 ipv4.addresses 10.200.142.132/16
# cat /etc/sysconfig/network-scripts/ifcfg-ens192
# systemctl restart NetworkManager
# systemctl restart network

// 変更後のIPに対して疎通確認をする
# ping -c 8 10.60.142.132
# ping -c 8 10.200.142.132
``````````````````````````````
・ホスト名変更
``````````````````````````````
// spgcgi0904
# cat /etc/hostname
# hostnamectl set-hostname spgcgi0904
# cat /etc/hostname
``````````````````````````````
・cron,apache停止
``````````````````````````````
// spgcgi0904
# systemctl stop crond
# systemctl status crond
# systemctl stop httpd
# systemctl status httpd
``````````````````````````````
・ログ削除
下記ディレクトリ配下のログを削除する(rotateしているログ)
``````````````````````````````
/var/log
/var/log/httpd
/var/log/mysqlrouter
/var/log/applog
``````````````````````````````
・シャットダウン
``````````````````````````````
// spgcgi0904
# shutdown now
``````````````````````````````

shvcenter65.adi.estore.co.jp -> Shinkawa DC -> Production -> spgcgi0904 -> アクション -> 設定の編集 から、Network adapter1と2の パワーオン時に接続 をオンにする。
設定編集後、アクション -> 電源 からパワーオンにする。

・shcc2から疎通確認
``````````````````````````````
// shcc2
$ ping -c 8 10.60.142.132
$ ssh p-abe@10.200.142.132
``````````````````````````````
・cron,apache起動確認
``````````````````````````````
// spgcgi0904
# systemctl status crond
# systemctl status httpd
``````````````````````````````