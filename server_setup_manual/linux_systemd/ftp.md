■ 作業手順(ftpサーバ)

2. ftpインストール
参照
https://ja.unixlinux.online/zh/1007017169.html
``````````````````````````````
# dnf install -y vsftpd
``````````````````````````````

3. vsftpd.conf修正
``````````````````````````````
# vi /etc/vsftpd/vsftpd.conf
----------以下設定例-----------
//tcp_wrappers=YESは対応しないと500エラーになるため注意
anonymous_enable=NO
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
# useradd -m -s /bin/bash ftpuser
# passwd ftpuser
``````````````````````````````

5. テスト用ファイル作成
``````````````````````````````
# touch /home/ftpuser/hogefile.txt
# chown ftpuser:ftpuser /home/ftpuser/hogefile.txt
``````````````````````````````

6. ftp起動
``````````````````````````````
# systemctl start vsftpd
# systemctl enable vsftpd
# systemctl status vsftpd
``````````````````````````````

7. firewall許可設定
```````````````````````````````
# firewall-cmd --add-service=ftp --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
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

### 1. オレオレ証明書作成
```````````````````````````````
# openssl genrsa -out vsftpd.key 2048
# openssl req -out vsftpd.csr -key vsftpd.key -new
# openssl x509 -req -days 3650 -signkey vsftpd.key -in vsftpd.csr -out vsftpd.crt
# cat vsftpd.crt vsftpd.key > vsftpd.pem
# chmod 600 vsftpd.pem
// 確認
# openssl x509 -text < vsftpd.pem

# mv vsftpd.pem /etc/pki/tls/certs/
# mv vsftpd.key /etc/pki/tls/private/
```````````````````````````````

3. vsftpd.conf修正
``````````````````````````````
# vi /etc/vsftpd/vsftpd.conf
----------以下を追記-----------
# --- FTPS 必須設定 ---
ssl_enable=YES
allow_anon_ssl=NO
rsa_cert_file=/etc/pki/tls/certs/vsftpd.pem
rsa_private_key_file=/etc/pki/tls/private/vsftpd.key
require_ssl_reuse=NO

# --- 暗号化の強制 ---
force_local_logins_ssl=YES
force_local_data_ssl=YES

# --- 安全なプロトコルの指定（脆弱なものを明示的に拒否） ---
ssl_sslv2=NO
ssl_sslv3=NO
ssl_tlsv1=NO
ssl_tlsv1_1=NO
ssl_tlsv1_2=YES
ssl_tlsv1_3=YES

# --- Passive Mode Settings ---
pasv_enable=YES
pasv_min_port=50000
pasv_max_port=50050
``````````````````````````````

7. firewall許可設定
```````````````````````````````
// パッシブモードで使うポート範囲許可
# firewall-cmd --add-port=50000-50050/tcp --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
```````````````````````````````

5. selinux無効
```````````````````````````````
// vsftpd再起動時にpem読み込めないため
# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
```````````````````````````````

6. ftp再起動
``````````````````````````````
# systemctl restart vsftpd
# systemctl status vsftpd
``````````````````````````````


1. curlでダウンロード、アップロードテスト 
```````````````````````````````
// 明示的FTPS（Explicit FTPS）
// ftpsで指定すると、暗黙的FTPSとして最初から990に繋ぎに行って弾かれる
$ curl -k --ssl-reqd -u "ユーザー名:パスワード" -O ftp://ftpサーバのドメインorIP/remote/path/file.zip

例（ダウンロード）
# curl -k --ssl-reqd -u ftpuser:8441 -O ftp://172.28.10.16/hogefile.txt
（アップロード）
# curl -k --ssl-reqd -T ./hogeee.txt -u ftpuser:8441 ftp://172.28.10.16/
※パスはホームディレクトリ以下からのパスで指定する
```````````````````````````````