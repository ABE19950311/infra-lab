■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること

■ 作業手順(ftpサーバ)

1. host名変更
```````````````````````````````
// ftpサーバ
$ hostnamectl set-hostname ホスト名
$ hostname
```````````````````````````````

2. ftpインストール
参照
https://ja.unixlinux.online/zh/1007017169.html
``````````````````````````````
$ sudo -i or su -
# dnf install -y vsftpd
# systemctl start vsftpd
# systemctl status vsftpd
``````````````````````````````

3. vsftpd.conf修正
``````````````````````````````
# vi /etc/vsftpd/vsftpd.conf
----------以下設定例-----------
//tcp_wrappers=YESは対応しないと500エラーになるため注意
anonymous_enable=YES
local_enable=YES
write_enable=YES
local_umask=022
#anon_upload_enable=YES
#anon_mkdir_write_enable=YES
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
#chown_uploads=YES
#chown_username=whoever
#xferlog_file=/var/log/xferlog
xferlog_std_format=YES
#idle_session_timeout=600
#data_connection_timeout=120
#nopriv_user=ftpsecure
#async_abor_enable=YES
#ascii_upload_enable=YES
#ascii_download_enable=YES
#ftpd_banner=Welcome to blah FTP service.
#deny_email_enable=YES
#banned_email_file=/etc/vsftpd/banned_emails
#chroot_local_user=YES
#chroot_list_enable=YES
#chroot_list_file=/etc/vsftpd/chroot_list
#ls_recurse_enable=YES
listen=YES
#listen_ipv6=YES
pam_service_name=vsftpd
userlist_enable=YES
#tcp_wrappers=YES
``````````````````````````````

4. ftp用ユーザ作成と追加
``````````````````````````````
# useradd -m ftpuser
# passwd ftpuser
``````````````````````````````

5. テスト用ファイル作成
``````````````````````````````
# touch /home/ftpuser/hogefile.txt
# chown ftpuser:ftpuser /home/ftpuser/hogefile.txt
``````````````````````````````

6. ftp再起動
``````````````````````````````
# systemctl restart vsftpd
``````````````````````````````

7. firewall,selinuxが無効になっている事を確認
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


■ 作業手順(ftpクライアント)
https://totech.hateblo.jp/entry/2015/04/16/231035

1. curlでダウンロード、アップロードテスト 
```````````````````````````````
$ curl -u "ユーザー名:パスワード" -O ftp://ftpサーバのドメインorIP/remote/path/file.zip
例（ダウンロード）
# curl -u ftpuser:8441 -O ftp://172.28.10.16/hogefile.txt
（アップロード）
# curl -T ./hogeee.txt -u ftpuser:8441 ftp://172.28.10.16/
※パスはホームディレクトリ以下からのパスで指定する
```````````````````````````````

■ ftps化（パッシブモード）
https://dev.classmethod.jp/articles/ftps_on_centos7/
