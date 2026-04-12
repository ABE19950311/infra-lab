## ■ dbサーバ構築(mysql)

### 1. mysqlインストール
```````````````````````````````
# dnf install -y mysql-server
# systemctl start mysqld
# systemctl enable mysqld
# systemctl status mysqld
```````````````````````````````

### 2. 初期設定
```````````````````````````````
# mysql_secure_installation
---------------------------------
Press y|Y for Yes, any other key for No: Yes
Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG: 0
Please set the password for root here.

New password: 

Re-enter new password: 

Estimated strength of the password: 50 
Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) : y

Remove anonymous users? (Press y|Y for Yes, any other key for No) : y

Disallow root login remotely? (Press y|Y for Yes, any other key for No) : n

Remove test database and access to it? (Press y|Y for Yes, any other key for No) : y

Reload privilege tables now? (Press y|Y for Yes, any other key for No) : y
Success.

All done!
-----------------------
```````````````````````````````

### 3. ファイアウォール許可設定
```````````````````````````````
# firewall-cmd --list-all
# firewall-cmd --add-service=mysql --zone=public --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
```````````````````````````````

### 4. テスト用データベース、テーブル作成
```````````````````````````````
# mysql -u root -p
mysql> CREATE DATABASE test CHARACTER SET utf8mb4;
mysql> CREATE USER 'sample_user' IDENTIFIED BY 'hoge';
// パスワードポリシーに引っかかって、緩める場合以下実行
mysql> SET GLOBAL validate_password.policy=LOW;
mysql> SET GLOBAL validate_password.length=4;

mysql> GRANT ALL PRIVILEGES ON test.* TO 'sample_user'@'%';
mysql> FLUSH PRIVILEGES;
mysql> USE test;
mysql> CREATE TABLE hoge (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
mysql> exit;
```````````````````````````````