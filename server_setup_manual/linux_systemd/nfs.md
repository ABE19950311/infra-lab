■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること


■　nfsサーバ作業手順
※nfsサーバとnfsクライアントがある。
　nfsサーバ=EFS,FSx クライアント=EC2
  https://tech.tiger-rack.co.jp/programming/nfs_setup/

0. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

1. 関連パッケージインストール
``````````````````````````````````
# dnf install -y nfs-utils
# systemctl start nfs-server
⇒上記で他必要なサービスも起動する
# systemctl enable nfs-server
# systemctl status nfs-server
``````````````````````````````````

2. 公開ディレクトリと設定
※docker環境はファイルシステムがoverlayでnfsに対応してない
　ファイルシステムのため、エラーが出る
　exportfs: /nfs does not support NFS export
　そのため、ext4ファイルシステムを作って、それを対象にする
````````````````````````````````
// 1GBのからファイル作成
# dd if=/dev/zero of=/srv/nfs_disk.img bs=1M count=1024
// 対象ファイルにext4ファイルシステム作成
# mkfs.ext4 /srv/nfs_disk.img
// 公開ディレクトリと上記ext4の仮想ファイルシステム作成
# mkdir -p /srv/nfs
# mount -o loop /srv/nfs_disk.img /srv/nfs

# vi /etc/exports
----------以下を追記する-----------
/srv/nfs 172.28.0.0/16(rw,async,no_root_squash)

# exportfs -rv
``````````````````````````````````

3. firewall,selinuxが無効になっている事を確認
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

■　nfsクライアント作業手順

1. 関連パッケージインストール
``````````````````````````````````
# dnf install -y nfs-utils
``````````````````````````````````

2. マウント用ディレクトリ作成とマウント
``````````````````````````````````
# mkdir /mnt/nfs
# mount -v -t nfs 172.28.10.15(nfsサーバのIP):/srv/nfs /mnt/nfs
// 確認
# mount
# cd /mnt/nfs/
# touch hoge
⇒nfsサーバの公開ディレクトリにhogeファイルがあることを確認する
``````````````````````````````````

3. 自動マウント設定
``````````````````````````````````
# vi /etc/fstab
----------以下を追記する-----------
172.28.10.15:/srv/nfs  /mnt/nfs  nfs  rw,vers=3,rsize=1048576,wsize=1048576,hard,tcp,timeo=600,retrans=2,sec=sys  0 0

# umount /mnt/nfs
# mount -a
⇒マウントされることを確認する
``````````````````````````````````