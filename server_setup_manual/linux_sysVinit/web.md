■ web (httpd)

### 1. apache、mod_ssl、opensslインストール
```````````````````````````````
# yum install -y httpd mod_ssl openssl
```````````````````````````````

### 2. apサーバへのプロキシ設定追加
```````````````````````````````
// デフォルトのssl.confを退避
# mv /etc/httpd/conf.d/ssl.conf /etc/httpd/conf.d/ssl.conf.org
# vi /etc/httpd/conf.d/vhost.conf
---------以下を追加する---------
# 以下の1行を先頭に追加して、mod_sslを読み込ませる
LoadModule ssl_module modules/mod_ssl.so

NameVirtualHost *:80
NameVirtualHost *:443

# HTTP: リダイレクトのみ
<VirtualHost *:80>
    ServerName webサーバIP,ドメイン,localhost
    Redirect permanent / https://webサーバIP,ドメイン,localhost/
</VirtualHost>

# HTTPS: 実際の処理はこちら
Listen 443
<VirtualHost *:443>
    ServerName webサーバIP,ドメイン,localhost
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/httpd/conf.d/certs/server.crt
    SSLCertificateKeyFile /etc/httpd/conf.d/certs/server.key
    # 必要に応じて中間証明書も指定
    # SSLCertificateChainFile /etc/pki/tls/certs/chain.crt

    # PHP-FPM(apサーバー)への連携 (mod_fastcgiを使用)
    <IfModule mod_fastcgi.c>
        # ダミーのFastCGIスクリプトパスを定義し、apサーバへ転送
        FastCgiExternalServer /var/www/html/php.fcgi -host apサーバのIP:9000
        AddHandler php-fastcgi .php
        Action php-fastcgi /php.fcgi
    </IfModule>

    DirectoryIndex index.php
    <Directory "/var/www/html">
        AllowOverride All
        # Apache 2.2用のアクセス許可構文
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>
```````````````````````````````

### 3. オレオレ証明書作成
```````````````````````````````
# openssl genrsa -out server.key 2048
# openssl req -out server.csr -key server.key -new
# vi san.txt
----------以下内容を追記---------
// IP,ドメインで内容は適宜変更する
subjectAltName = IP:webサーバのIP
            or
subjectAltName=DNS:localhost,IP:127.0.0.1
subjectAltName=DNS:*.hoge.com,DNS:hoge.com,IP:webサーバIP

# openssl x509 -req -days 3650 -signkey server.key -in server.csr -out server.crt -extfile san.txt
// 確認
# openssl x509 -text < server.crt

// pem
# cat server.crt server.key > server.pem
```````````````````````````````

### 4. オレオレ証明書適用
```````````````````````````````
# mkdir -p /etc/httpd/conf.d/certs
# mv server.crt server.key /etc/httpd/conf.d/certs/
# chown -R root:root /etc/httpd/conf.d/certs
# chmod 755 /etc/httpd/conf.d/certs
# chmod 644 /etc/httpd/conf.d/certs/server.crt
# chmod 600 /etc/httpd/conf.d/certs/server.key
実施後、ブラウザ側でオレオレ証明書のインポートとブラウザ再起動をする
参照chrome
※証明書は、「信頼されたルート証明機関」配下にインポートする
https://kekaku.addisteria.com/wp/20190327053337#toc7
```````````````````````````````

### 5. firewall許可,selinux無効
```````````````````````````````
# iptables -I RH-Firewall-1-INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
# iptables -I RH-Firewall-1-INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
# service iptables save
# service iptables restart
# iptables -L -n

# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
```````````````````````````````

### 6. httpd起動確認
```````````````````````````````
# service httpd start
# chkconfig httpd on
# service httpd status
```````````````````````````````