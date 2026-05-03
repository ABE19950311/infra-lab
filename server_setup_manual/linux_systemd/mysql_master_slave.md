■ master側レプリケーション作業手順(gtid)

1. my.cnf修正
```````````````````````````````````````
# vi /etc/my.cnf.d/mysql-server.cnf
// server-idは重複しないようにする
----------------以下を追記--------------
[mysqld]
log-bin
server-id=101
# 既存の設定に以下を追加
gtid_mode = ON
enforce_gtid_consistency = ON
# Slave側でもバイナリログを出力させ、GTIDを保持するために必要
log_slave_updates = ON

# systemctl restart mysqld
```````````````````````````````````````

2. レプリケーション用ユーザ作成
```````````````````````````````````````
# mysql -u root -p
mysql> create user 'repl'@'%' identified by 'pass';
mysql> grant replication slave on *.* to 'repl'@'%';
mysql> exit;
```````````````````````````````````````

3. デーベースdump
```````````````````````````````````````
# mysqldump -u root -p --all-databases --single-transaction --flush-logs --quick --master-data=2 > master.db
```````````````````````````````````````

■ slave側レプリケーション作業手順(gtid)

1. my.cnf修正
```````````````````````````````````````
# vi /etc/my.cnf.d/mysql-server.cnf
// slave中に書き込みさせないためread_onlyにする
----------------以下を追記--------------
[mysqld]
log-bin
server-id=102
read_only
# 既存の設定に以下を追加
gtid_mode = ON
enforce_gtid_consistency = ON
# Slave側でもバイナリログを出力させ、GTIDを保持するために必要
log_slave_updates = ON

# systemctl restart mysqld
```````````````````````````````````````

2. dumpファイルリストアとポジション番号確認
```````````````````````````````````````
# mysql -u root -p < master.db
# cat master.db | grep "CHANGE MASTER TO MASTER_LOG_FILE"
⇒内容を保存しておく
```````````````````````````````````````

3. slave設定
```````````````````````````````````````
# mysql -u root -p
mysql> CHANGE MASTER TO
MASTER_HOST='172.28.10.8',
MASTER_PORT=3306,
MASTER_USER='repl',
MASTER_PASSWORD='pass',
MASTER_AUTO_POSITION = 1;
```````````````````````````````````````

4. slave開始とステータス確認
```````````````````````````````````````
mysql> start slave;
mysql> show slave status\G;
mysql> exit;

// Authentication plugin 'caching_sha2_password'...と出る場合は以下を実行する
mysql> stop slave;
mysql> CHANGE MASTER TO GET_MASTER_PUBLIC_KEY=1;
mysql> start slave;
mysql> show slave status\G;
mysql> exit;
```````````````````````````````````````

■ replication復旧手順(gtid)

1. slaveを止める
```````````````````````````````````````
// slave
# mysql -u root
mysql> show slave status\G
⇒Error reconnectingになっていること確認
mysql> STOP SLAVE;
// リストアする際にERROR 3546 (HY000) at line 26: @@GLOBAL.GTID_PURGED cannot be changed: the added gtid set must not overlap with @@GLOBAL.GTID_EXECUTED と出るため
mysql> RESET MASTER;
mysql> show slave status\G
⇒ないことを確認
mysql> exit;
```````````````````````````````````````

2. masterDBdump
```````````````````````````````````````
// master
# mysqldump -u root -p --all-databases --single-transaction --flush-logs --quick --master-data=2 > master.db
```````````````````````````````````````

3. dumpファイルリストア
```````````````````````````````````````
// slave
# mysql -u root -p < master.db

# mysql -u root -p
mysql> CHANGE MASTER TO
MASTER_HOST='172.28.10.8',
MASTER_PORT=3306,
MASTER_USER='repl',
MASTER_PASSWORD='pass',
MASTER_AUTO_POSITION = 1;
mysql> start slave;
mysql> show slave status\G;
```````````````````````````````````````


--------------------------------------------


■ master側レプリケーション作業手順(gtidなし)

1. my.cnf修正
```````````````````````````````````````
# vi /etc/my.cnf.d/mysql-server.cnf
// server-idは重複しないようにする
----------------以下を追記--------------
[mysqld]
log-bin
server-id=101

# systemctl restart mysqld
```````````````````````````````````````

2. レプリケーション用ユーザ作成
```````````````````````````````````````
# mysql -u root -p
mysql> create user 'repl'@'%' identified by 'pass';
mysql> grant replication slave on *.* to 'repl'@'%';
mysql> exit;
```````````````````````````````````````

3. デーベースdump
```````````````````````````````````````
# mysqldump -u root -p --all-databases --single-transaction --flush-logs --quick --master-data=2 > master.db
```````````````````````````````````````

■ slave側レプリケーション作業手順(gtidなし)

1. my.cnf修正
```````````````````````````````````````
# vi /etc/my.cnf.d/mysql-server.cnf
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
# mysql -u root -p < master.db
# cat master.db | grep "CHANGE MASTER TO MASTER_LOG_FILE"
⇒内容を保存しておく
```````````````````````````````````````

3. slave設定
```````````````````````````````````````
# mysql -u root -p
mysql> CHANGE MASTER TO
MASTER_HOST='172.28.10.8',
MASTER_PORT=3306,
MASTER_USER='repl',
MASTER_PASSWORD='pass',
MASTER_LOG_FILE='<手順2で確認したファイル名>',
MASTER_LOG_POS=<手順2で確認したポジション番号>;
```````````````````````````````````````

4. slave開始とステータス確認
```````````````````````````````````````
mysql> start slave;
mysql> show slave status\G;
mysql> exit;

// Authentication plugin 'caching_sha2_password'...と出る場合は以下を実行する
mysql> stop slave;
mysql> CHANGE MASTER TO GET_MASTER_PUBLIC_KEY=1;
mysql> start slave;
mysql> show slave status\G;
mysql> exit;
```````````````````````````````````````

■ replication復旧手順(gtidなし)

1. slaveを止める
```````````````````````````````````````
// slave
# mysql -u root
mysql> show slave status\G
⇒Error reconnectingになっていること確認
mysql> STOP SLAVE;
mysql> RESET SLAVE;
mysql> show slave status\G
⇒ないことを確認
mysql> exit;
```````````````````````````````````````

2. masterDBdump
```````````````````````````````````````
// master
# mysqldump -u root -p --all-databases --single-transaction --flush-logs --quick --master-data=2 > master.db
```````````````````````````````````````

3. dumpファイルリストア
```````````````````````````````````````
// slave
# mysql -u root -p < master.db
# cat master.db | grep "CHANGE MASTER TO MASTER_LOG_FILE"
⇒内容を保存しておく

# mysql -u root -p
mysql> CHANGE MASTER TO
MASTER_HOST='172.28.10.8',
MASTER_PORT=3306,
MASTER_USER='repl',
MASTER_PASSWORD='pass',
MASTER_LOG_FILE='<ここで確認したファイル名>',
MASTER_LOG_POS=<ここで確認したポジション番号>;
mysql> start slave;
mysql> show slave status\G;
```````````````````````````````````````