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
Securing the MySQL server deployment.

Connecting to MySQL using a blank password.

VALIDATE PASSWORD COMPONENT can be used to test passwords
and improve security. It checks the strength of password
and allows the users to set only those passwords which are
secure enough. Would you like to setup VALIDATE PASSWORD component?

Press y|Y for Yes, any other key for No: Yes

There are three levels of password validation policy:

LOW    Length >= 8
MEDIUM Length >= 8, numeric, mixed case, and special characters
STRONG Length >= 8, numeric, mixed case, special characters and dictionary                  file

Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG: 0
Please set the password for root here.

New password: 

Re-enter new password: 

Estimated strength of the password: 50 
Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) : y
By default, a MySQL installation has an anonymous user,
allowing anyone to log into MySQL without having to have
a user account created for them. This is intended only for
testing, and to make the installation go a bit smoother.
You should remove them before moving into a production
environment.

Remove anonymous users? (Press y|Y for Yes, any other key for No) : y
Success.


Normally, root should only be allowed to connect from
'localhost'. This ensures that someone cannot guess at
the root password from the network.

Disallow root login remotely? (Press y|Y for Yes, any other key for No) : n

 ... skipping.
By default, MySQL comes with a database named 'test' that
anyone can access. This is also intended only for testing,
and should be removed before moving into a production
environment.


Remove test database and access to it? (Press y|Y for Yes, any other key for No) : y
 - Dropping test database...
Success.

 - Removing privileges on test database...
Success.

Reloading the privilege tables will ensure that all changes
made so far will take effect immediately.

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

### 2. 外部接続許可用ユーザ作成
```````````````````````````````
# mysql -u root -p
mysql> CREATE USER 'sample_user' IDENTIFIED BY 'hoge';
mysql> GRANT ALL PRIVILEGES ON *.* TO 'sample_user'@'%' WITH GRANT OPTION;
```````````````````````````````

### 3. テスト用データベース、テーブル作成
```````````````````````````````
mysql> CREATE DATABASE todoapp CHARACTER SET utf8mb4;
mysql> USE todoapp;
mysql> CREATE TABLE todos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
mysql> exit;
```````````````````````````````