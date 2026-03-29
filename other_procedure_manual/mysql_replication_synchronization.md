#### splogdb0102_レプリケーション再構築作業

■目的・概要
splogdb0102の/home Diskが81%となっていたため調査したところ、DBのテーブルが壊れていることが判明した。
マスター側（splogdb0101）からコピーし、DBの再構築作業を実施する。

■対象ホスト
splogdb0101 splogdb0102

■事前作業
shnagiosで対象サーバの監視通知をオフにする。
https://shnag.estore.co.jp/nagios/
	Disable notifications for all services on this host
	Disable checks of all services on this host

■作業手順
1.shcc2からsplogdb0102に接続
$ ssh nfs-splogdb0102

2.rootに遷移
-sh-3.2$ su -
pass/root21世代

3.現在のDISK状況の確認
[root@splogdb0102 ~]# df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/cciss/c0d0p2     9.5G  3.6G  5.5G  40% /
/dev/cciss/c0d0p5     382G  292G   72G  81% /home    ★
/dev/cciss/c0d0p1      99M   12M   82M  13% /boot
tmpfs                  36G     0   36G   0% /dev/shm
〜〜

4.ファイル容量の確認
[root@splogdb0102 ~]# ls -lSh /home/local/mysql/var/log_master/ | head -10
total 176G
-rw-rw---- 1 mysql mysql  84G Apr  7 12:33 hour_object.MYD
-rw-rw---- 1 mysql mysql  26G Apr  7 13:20 hour_object.MYI
-rw-rw---- 1 mysql mysql  13G Apr  7 13:28 hour_from.MYD
-rw-rw---- 1 mysql mysql 9.8G Apr  7 02:06 day_object_bak.MYD
-rw-rw---- 1 mysql mysql 8.4G Apr  7 13:28 hour_from.MYI
-rw-rw---- 1 mysql mysql 6.2G Apr  7 13:28 hour_brwsr.MYD
-rw-rw---- 1 mysql mysql 5.5G Apr  7 13:28 hour_os.MYD
-rw-rw---- 1 mysql mysql 4.5G Apr  7 13:28 hour_referer.MYD
-rw-rw---- 1 mysql mysql 4.0G Apr  7 13:28 hour_brwsr.MYI

5.splogdb0102のテーブル状態を確認
[root@splogdb0102 ~]# mysql -u root -p

mysql> show databases;
+--------------------+
| Database           |
+--------------------+
| information_schema |
| log_master         |
| mysql              |
| test               |
+--------------------+
4 rows in set (0.00 sec)
mysql> use log_master;
mysql> CHECK TABLE hour_object;
+------------------------+-------+----------+-------------------------------------------------------------+
| Table                  | Op    | Msg_type | Msg_text                                                    |
+------------------------+-------+----------+-------------------------------------------------------------+
| log_master.hour_object | check | warning  | Table is marked as crashed                                  |
| log_master.hour_object | check | error    | Record-count is not ok; is 818925331   Should be: 809466668 |
| log_master.hour_object | check | warning  | Found 798711916 deleted space.   Should be 0                |
| log_master.hour_object | check | warning  | Found 7218107 deleted blocks       Should be: 0             |
| log_master.hour_object | check | warning  | Found 826143438 key parts. Should be: 809466668             |
| log_master.hour_object | check | error    | Corrupt                                                     |
+------------------------+-------+----------+-------------------------------------------------------------+
6 rows in set (23 min 43.37 sec)

mysql> exit
Bye

6.splogdb0102のレプリケーションを停止する
※実施のタイミングとして処理が終了していることを確認する。
※ログの解析時間を避けるため、xx:20〜xx:00の間で実施する。
http://210.248.168.105:40080/log_status_sps25-1.php
上記を確認して処理中(セルが赤色)になっていないこと。

[root@splogdb0102 ~]# mysql -u root -p

mysql> show slave status\G

mysql> stop slave;

mysql> exit

7.対象データの確認
[root@splogdb0102 ~]# cd /home/local/mysql/var/
[root@splogdb0102 var]# ls -lat log_master/
total 184307800
-rw-rw---- 1 mysql mysql  6567534684 Apr  7 14:40 hour_brwsr.MYD
-rw-rw---- 1 mysql mysql  4274578432 Apr  7 14:40 hour_brwsr.MYI
-rw-rw---- 1 mysql mysql 13394002400 Apr  7 14:40 hour_from.MYD
-rw-rw---- 1 mysql mysql  8961431552 Apr  7 14:40 hour_from.MYI
-rw-rw---- 1 mysql mysql    88523948 Apr  7 14:38 all_counts.MYD
-rw-rw---- 1 mysql mysql    61460480 Apr  7 14:38 all_counts.MYI
-rw-rw---- 1 mysql mysql 89212511868 Apr  7 14:38 hour_object.MYD
-rw-rw---- 1 mysql mysql 27070819328 Apr  7 14:38 hour_object.MYI
-rw-rw---- 1 mysql mysql   174143184 Apr  7 13:28 hour_srch_eng.MYD
-rw-rw---- 1 mysql mysql    89566208 Apr  7 13:28 hour_srch_eng.MYI
-rw-rw---- 1 mysql mysql   636483552 Apr  7 13:28 hour_srch_key.MYD
-rw-rw---- 1 mysql mysql   173041664 Apr  7 13:28 hour_srch_key.MYI
-rw-rw---- 1 mysql mysql  4782931876 Apr  7 13:28 hour_referer.MYD
-rw-rw---- 1 mysql mysql  1401859072 Apr  7 13:28 hour_referer.MYI
〜〜

8.対象のディレクトリを削除
[root@splogdb0102 var]# rm -rf log_master/*

9.削除できたことを確認
[root@splogdb0102 var]# ls -lat log_master/*

10.マスター側FileとPositionを確認 ※メモしておく
-sh-4.2$ ssh root@nfs-splogdb0101a

[root@splogdb0101a ~]# mysql -u root -p -e "show master status"
Enter password:
+------------------+-----------+--------------+------------------+
| File             | Position  | Binlog_Do_DB | Binlog_Ignore_DB |
+------------------+-----------+--------------+------------------+
| logdb-bin.009312 | 702433729 |              |                  |
+------------------+-----------+--------------+------------------+

11.マスターの対象ディレクトリを確認
[root@splogdb0101a ~]# cd /home/local/mysql/var
[root@splogdb0101a var]# ls -lat log_master/
total 23183312
-rw-rw---- 1 mysql mysql     6879904 Apr  7 14:20 hour_srch_key.MYD
-rw-rw---- 1 mysql mysql     1615872 Apr  7 14:20 hour_srch_key.MYI
-rw-rw---- 1 mysql mysql     4548880 Apr  7 14:20 readiness.MYD
-rw-rw---- 1 mysql mysql     5369856 Apr  7 14:20 readiness.MYI
-rw-rw---- 1 mysql mysql     1912872 Apr  7 14:20 hour_srch_eng.MYD
-rw-rw---- 1 mysql mysql      934912 Apr  7 14:20 hour_srch_eng.MYI
-rw-rw---- 1 mysql mysql    53317232 Apr  7 14:20 hour_referer.MYD
-rw-rw---- 1 mysql mysql    12091392 Apr  7 14:20 hour_referer.MYI
-rw-rw---- 1 mysql mysql    78259440 Apr  7 14:20 hour_os.MYD
-rw-rw---- 1 mysql mysql    38389760 Apr  7 14:20 hour_os.MYI
-rw-rw---- 1 mysql mysql    88549056 Apr  7 14:20 hour_brwsr.MYD
-rw-rw---- 1 mysql mysql    42165248 Apr  7 14:20 hour_brwsr.MYI
〜〜

12.容量の確認
[root@splogdb0101a var]# df -h
Filesystem            Size  Used Avail Use% Mounted on
/dev/sda2              19G  4.0G   15G  22% /
/dev/sda1              99M   26M   69M  28% /boot
tmpfs                  18G     0   18G   0% /dev/shm
/dev/drbd0            315G  134G  166G  45% /home/local/mysql　★コピー作成に十分な空き容量があること
～

13.マスター側の対象ディレクトリサイズを確認
[root@splogdb0101a var]# du -sh /home/local/mysql/var/log_master/
23G     /home/local/mysql/var/log_master/
⇒/home/local/mysql配下の空き容量は166Gなので問題なし。

14.対象ディレクトリをコピー(スレーブにコピーする途中にマスターが更新されるのを防ぐため)
[root@splogdb0101a var]# cp -ar log_master log_master_copy

15.コピーしたディレクトリをスレーブ側（splogdb0102）にコピーする。
・dry-run
[root@splogdb0101a var]# rsync -avn log_master_copy/* root@10.200.132.87:/home/local/mysql/var/log_master
→問題なければ以下実行

[root@splogdb0101a var]# rsync -av log_master_copy/* root@10.200.132.87:/home/local/mysql/var/log_master

16.対象のファイルが存在することを確認 ※オーナーグループがmysqlであること、log_masterのパーミッションが700（drwx------）になっていることも確認。
[root@splogdb0102 ~]# ls -lt /home/local/mysql/var/log_master
[root@splogdb0102 ~]# ls -lat /home/local/mysql/var/

17.スレーブをマスターと合わせるため、レプリケーションの設定を変更
[root@splogdb0102 ~]# mysql -u root -p

mysql> SHOW SLAVE STATUS \G

mysql> CHANGE MASTER TO MASTER_LOG_FILE = 'logdb-bin.009312',MASTER_LOG_POS = 702433729; 
MASTER_LOG_FILE、MASTER_LOG_POSには10.で確認した値を入力する。

18.変更が反映されているか確認
mysql> SHOW SLAVE STATUS \G

19.splogdb0102（スレーブ）のレプリケーションを再開
mysql> start slave;

mysql> SHOW SLAVE STATUS \G
→再開されたことを確認

20.splogdb0102で現在のDISK容量が下がっているかを確認。
[root@splogdb0102 ~]# df -h

21.対象ディレクトリサイズが下がっているかを確認
[root@splogdb0102 ~]# ls -lahS /home/local/mysql/var/log_master/

22.nagiosでsplogdb0102の状態を確認
https://shnag.estore.co.jp/nagios/

23.マスター側でコピーに使用したディレクトリの削除
[root@splogdb0101a ~]# cd /home/local/mysql/var/
[root@splogdb0101a ~]# rm -rf log_master_copy

24.Nagiosの監視を再開
https://shnag.estore.co.jp/nagios/

------------------------------------------------------------------------------------
■解消しなかった場合
DB全体をコピーし、上記と同様の手順で再試行

・splogdb0101のデータディレクトリ
/var/lib/mysql/mysql

・splogdb0102のデータディレクトリ
/home/local/mysql/var/mysql

------------------------------------------------------------------------------------


■作業影響・周知
・サービスへの影響はなし
・slack,メールで周知