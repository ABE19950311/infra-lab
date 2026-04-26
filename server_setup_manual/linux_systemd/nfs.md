■　nfsサーバ作業手順
※nfsサーバとnfsクライアントがある。
　nfsサーバ=EFS,FSx クライアント=EC2
  https://tech.tiger-rack.co.jp/programming/nfs_setup/

1. 関連パッケージインストール
``````````````````````````````````
# dnf install -y nfs-utils
# systemctl start nfs-server
⇒上記で他必要なサービスも起動する
# systemctl enable nfs-server
# systemctl status nfs-server
``````````````````````````````````

2. 公開ディレクトリと設定
``````````````````````````````````
# 1. 普通に公開用のディレクトリを作るだけ
# mkdir -p /srv/nfs

# 2. すぐにエクスポート設定を追記する
# vi /etc/exports
/srv/nfs 共有許可IP/CIDR(rw,async,no_root_squash)

# 3. 設定を反映する
# exportfs -rv
``````````````````````````````````

3. 公開ディレクトリと設定(dockerの場合)
``````````````````````````````````
※docker環境はファイルシステムがoverlayでnfsに対応してない
　ファイルシステムのため、エラーが出る
　exportfs: /nfs does not support NFS export
　そのため、ext4ファイルシステムを作って、それを対象にする
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

# vi /etc/fstab
----------以下を追記する-----------
/srv/nfs_disk.img  /srv/nfs  ext4  loop  0 0

# exportfs -rv
``````````````````````````````````

4. firewall許可,selinux無効
```````````````````````````````
# firewall-cmd --add-service=nfs --permanent
# firewall-cmd --add-service=rpc-bind --permanent
# firewall-cmd --add-service=mountd --permanent
# firewall-cmd --reload
# firewall-cmd --list-all

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