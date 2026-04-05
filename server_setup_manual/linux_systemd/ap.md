## ■ apサーバ構築(php,php-fpm)

### 1. php,php-fpmインストール
```````````````````````````````
# dnf install -y php php-cli php-fpm php-mysqlnd php-pdo
```````````````````````````````

### 2. php-fpm listen設定
```````````````````````````````
# vi /etc/php-fpm.d/www.conf
---------以下内容で修正---------
// 9000portでlistenするようにする
listen = apサーバのIP:9000
// デフォルトはlocalhostを許可してるため、webサーバのIPを許可する
listen.allowed_clients = webサーバのIP
```````````````````````````````

### 3. 疎通確認用テストファイル作成
```````````````````````````````
# echo "<?php phpinfo(); ?>" > /var/www/html/index.php
# chown -R apache:apache /var/www/html
```````````````````````````````

### 4. firewall許可,selinux無効
```````````````````````````````
# firewall-cmd --add-port=9000/tcp --zone=public --permanent
# firewall-cmd --reload
# firewall-cmd --list-all

# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
```````````````````````````````

### 5. php-fpm起動確認
```````````````````````````````
# systemctl start php-fpm
# systemctl enable php-fpm
# systemctl status php-fpm
```````````````````````````````