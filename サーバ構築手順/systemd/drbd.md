■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること
・同期対象として、db作成手順もとに、primary,secondary両方にmysqlを入れておくこと
・切り替えはスイッチオーバ


・WSL上だと厳しそう

■ 作業手順

1. host名変更
```````````````````````````````
// drbd(primary,secondary)
$ hostnamectl set-hostname ホスト名
$ hostname
```````````````````````````````

2. drbdインストール
```````````````````````````````
// 両node
$ sudo -i
# sudo rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
// AlmaLinux 8用
# dnf install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
# dnf install -y drbd90-utils kmod-drbd90
```````````````````````````````

3. 
```````````````````````````````
```````````````````````````````