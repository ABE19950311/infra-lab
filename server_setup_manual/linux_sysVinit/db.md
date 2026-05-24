## ■ dbサーバ構築(mysql)

### 1. mysqlインストール
```````````````````````````````
# yum install -y mysql-server
# service mysqld start
# chkconfig mysqld on
# service mysqld status
```````````````````````````````

### 2. 初期設定
```````````````````````````````
# mysql_secure_installation
---------------------------------
Enter current password for root (enter for none): (そのままEnter)
Set root password? [Y/n] Y
New password: (パスワード入力)
Re-enter new password: (パスワード入力)

Remove anonymous users? [Y/n] Y
Disallow root login remotely? [Y/n] n
Remove test database and access to it? [Y/n] Y
Reload privilege tables now? [Y/n] Y
---------------------------------
```````````````````````````````

### 3. ファイアウォール許可設定
```````````````````````````````
# iptables -I INPUT -p tcp -m tcp --dport 3306 -j ACCEPT
# service iptables save
# service iptables restart
# iptables -L -n
```````````````````````````````

### 4. テスト用データベース、テーブル作成
```````````````````````````````
# mysql -u root -p
-- CentOS 5時代のMySQLは utf8mb4 非対応のため utf8 を指定
CREATE DATABASE test CHARACTER SET utf8;

-- ユーザー作成と権限付与を同時に行う（古い書き方）
GRANT ALL PRIVILEGES ON test.* TO 'sample_user'@'%' IDENTIFIED BY 'hoge';
FLUSH PRIVILEGES;

USE test;

CREATE TABLE hoge (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

exit;
```````````````````````````````