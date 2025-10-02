■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること
・ansible未対応

■ 作業手順
全体設定参照
https://www.rem-system.com/mail-postfix01/

0. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

1. postfixインストール
```````````````````````````
# dnf install -y postfix
# systemctl start postfix
# systemctl enable postfix
# systemctl status postfix
```````````````````````````

2. 設定ファイル編集と反映
```````````````````````````
# vi /etc/postfix/main.cf
※myhostname,mydomainで指定するドメインは、どこのdnsサーバにも存在してない
　架空のドメインでも良い模様。
[root@dbc56a3925ae ~]# dig abc313232.com

; <<>> DiG 9.11.36-RedHat-9.11.36-16.el8_10.4 <<>> abc313232.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 8989
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 1, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 4096
;; QUESTION SECTION:
;abc313232.com.                 IN      A

;; AUTHORITY SECTION:
com.                    643     IN      SOA     a.gtld-servers.net. nstld.verisign-grs.com. 1752027508 1800 900 604800 900

;; Query time: 184 msec
;; SERVER: 127.0.0.11#53(127.0.0.11)
;; WHEN: Wed Jul 09 02:23:00 UTC 2025
;; MSG SIZE  rcvd: 115

----------以下を追記--------
myhostname = mail.abc313232.com
mydomain = abc313232.com
masquerade_domains = abc313232.com

# postconf -n
# postfix check
# systemctl restart postfix
```````````````````````````

3. firewall,selinuxが無効になっている事を確認
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

4. mailテスト送信
```````````````````````````````
# telnet localhost 25
mail from:test@abc313232.com
rcpt to:宛先メールアドレス
data
-----本文入力------
testmail
.
-----本文入力終わり------
quit

他サーバからmailコマンドで送る際の例は以下
# echo "testmail" | mail -s "sendtestmail" -S smtp=smtp://172.28.10.12:25 -r 送信元メールアドレス 宛先メールアドレス
```````````````````````````````

5. ログ確認
```````````````````````````````
# less /var/log/maillog
※ログファイル自体存在しない場合、以下を実施
# systemctl status rsyslog
⇒起動していなければstart、サービスが無い場合は以下
※syslogまたはrsyslogが動いてないとログ記録されない
参照 https://wa3.i-3-i.info/word14296.html
# dnf install -y rsyslog
# systemctl start rsyslog
# systemctl enable rsyslog
# systemctl status rsyslog
再度手順4でテストメールを送って、/var/log/maillogを確認する
```````````````````````````````