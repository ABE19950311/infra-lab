サーバ_ディスク拡張
※実務上で実施して問題ない経験確認済み

■ 目的
サーバの /opt ディスク使用率アラート発生に伴い、700GBから1TBへ300GBのディスク拡張を実施する。
サーバfooは拡張分の300GBの空き容量が不足しているため、ストレージをesxstd33に変更した後実施する。

■ 前提条件
以下の条件を全て満たすこと、満たさないと本手順では出来ない可能性が高い
・OSバージョンが少なくとも以下であること
[root@hoge ~]# cat /etc/redhat-release
CentOS Linux release 7.7.1908 (Core)
・lvmが少なくとも以下内容で動いていること
lvm2-lvmetad.service       loaded active running LVM2 metadata daemon
lvm2-monitor.service       loaded active exited  Monitoring of LVM2 mirrors,
lvm2-pvscan@8:16.service   loaded active exited  LVM2 PV scan on device 8:16
lvm2-pvscan@8:2.service    loaded active exited  LVM2 PV scan on device 8:2

■ 事前準備
作業対象ファイルシステム、ディスク、デバイスを確認しておくこと
# df -PhT
# lsblk
# fdisk -l 対象デバイス

■ 作業対象サーバ
1. hoge
2. foo


■ 作業手順(foo vMotion)
1. vcenterにログインする
https://hogevcenter.co.jp

2. 検索から、[foo]を検索して選択する

3. アクション -> 移行を クリックする

4. 以下の内容を選択する
・移行タイプの選択
「コンピューティング リソースとストレージの両方を変更します」

・コンピューティング リソースの選択
対象ストレージがある階層
　hogevcenter.co.jp -> データセンター -> Production -> esxstd33

・ストレージの選択
「esxstd33_intelP4600_4T」

・ネットワークの選択
　特に何もせず「NEXT」をクリック

・vMotion の優先順位の選択
　特に何もせず「NEXT」をクリック (vMotion を高優先度でスケジューリング（推奨） を選択)

・設定の確認:
　移行タイプ、コンピューティング リソース、ストレージを確認して「FINISH」をクリック


■ 確認作業
1. 移行元に対象ホストが存在しないこと
2. 移行先に対象ホストが存在すること
3. 移行先のストレージ空き容量に問題が無いこと



■ 作業手順(ディスク拡張)
※以下の作業を1台づつ実施する。

1. vcenterにログインする
https://hogevcenter.co.jp

2. 検索から、対象サーバを検索して選択する

3. アクション -> 設定の編集をクリックし、ハードディスク2 の容量を 1TB に変更する（対象ディスクは要件により要確認）

4. 対象サーバにssh接続する
````````````````````````````````
$ ssh <対象サーバ>
````````````````````````````````

5. 拡張した容量を認識させる
````````````````````````````````
// 対象サーバ
$ sudo -i
# echo 1 > /sys/block/sdb/device/rescan
// 容量確認
# fdisk -l /dev/sdb
````````````````````````````````

6. PV,VG を拡張する
````````````````````````````````
# pvresize /dev/sdb
// 拡張された事を確認
# pvdisplay
# vgdisplay
````````````````````````````````

7. LV を拡張する
````````````````````````````````
# lvextend -l +100%FREE /dev/datavg/opt
// 拡張された事を確認
# lvdisplay
````````````````````````````````

8. ファイルシステムを拡張する
````````````````````````````````
# xfs_growfs /opt
// 拡張された事を確認
# df -PhT
````````````````````````````````
