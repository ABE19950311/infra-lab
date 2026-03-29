■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・ミドルウェア
[root@c22383d8a0fb /]# mysql --version
mysql  Ver 8.0.41 for Linux on x86_64 (Source distribution)

https://www.tohoho-web.com/ex/mysql-replication.html
https://qiita.com/ksugawara61/items/fdd5ae9b78931540887f


■ master側レプリケーション作業手順

1. my.cnf修正
```````````````````````````````````````
# vi /etc/my.cnf
// server-idは重複しないようにする
----------------以下を追記--------------
[mysqld]
log-bin
server-id=101

# systemctl restart mysqld
```````````````````````````````````````

2. レプリケーション用ユーザ作成
```````````````````````````````````````
# mysql -u root
mysql> create user 'repl'@'%' identified by 'pass';
mysql> grant replication slave on *.* to 'repl'@'%';
mysql> exit;
```````````````````````````````````````

3. デーベースdump
```````````````````````````````````````
# mysqldump -u root -p --all-databases --single-transaction --master-data > master.db
```````````````````````````````````````

■ slave側レプリケーション作業手順

1. my.cnf修正
```````````````````````````````````````
# vi /etc/my.cnf
// slave中に書き込みさせないためread_onlyにする
----------------以下を追記--------------
[mysqld]
log-bin
server-id=102
read_only

# systemctl restart mysqld
```````````````````````````````````````

2. dumpファイルリストアとポジション番号確認
```````````````````````````````````````
# mysql -u root < master.db
# cat master.db | grep "CHANGE MASTER TO MASTER_LOG_FILE"
⇒内容を保存しておく
```````````````````````````````````````

3. slave設定
```````````````````````````````````````
# mysql -u root
mysql> CHANGE MASTER TO
MASTER_HOST='172.28.10.8',
MASTER_PORT=3306,
MASTER_USER='repl',
MASTER_PASSWORD='pass',
MASTER_LOG_FILE='1299dab1db14-bin.000001',
MASTER_LOG_POS=1528;
```````````````````````````````````````

4. slave開始とステータス確認
```````````````````````````````````````
mysql> start slave;
mysql> show slave status\G;
mysql> exit;
```````````````````````````````````````

■ 手動フェイルオーバー作業手順

1. masterのdbを停止する
```````````````````````````````````````
// master
# systemctl stop mysqld
```````````````````````````````````````

2. slaveでマスタ情報をリセットする
```````````````````````````````````````
// slave
# mysql -u root
mysql> show slave status\G
⇒Error reconnectingになっていること確認
mysql> STOP SLAVE;
mysql> RESET SLAVE ALL;
mysql> show slave status\G
⇒ないことを確認
mysql> show master status\G;
⇒Fileとpositionを保存しておく
mysql> exit;
```````````````````````````````````````

3. read_only設定を除外してmysql再起動
```````````````````````````````````````
// slave
# vi /etc/my.cnf
----------------以下内容で修正--------------
[mysqld]
log-bin
server-id=102
#read_only

# systemctl restart mysqld
```````````````````````````````````````

4. デーベースdump
```````````````````````````````````````
// slave
# mysqldump -u root -p --all-databases --single-transaction --master-data > master.db
```````````````````````````````````````

5. slave再設定
```````````````````````````````````````
// 元master
// read_onlyにする
# vi /etc/my.cnf
[mysqld]
log-bin
server-id=101
read_only

# systemctl start mysqld
# mysql -u root
mysql> CHANGE MASTER TO
MASTER_HOST='172.28.10.9',
MASTER_PORT=3306,
MASTER_USER='repl',
MASTER_PASSWORD='pass',
MASTER_LOG_FILE='',
MASTER_LOG_POS=;
mysql> start slave;
mysql> show slave status\G;
```````````````````````````````````````