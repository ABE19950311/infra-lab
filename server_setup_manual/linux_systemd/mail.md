## Postfix+Dovecot

■ 作業手順

2. postfix、dovecotインストール
```````````````````````````
# dnf install -y postfix dovecot
```````````````````````````

3. 587portとsmtp認証を有効にする(postfix)
```````````````````````````
# vi /etc/postfix/master.cf
----------以下内容で編集------------------------
// -oの前の半角を消さない事
submission inet n       -       n       -       -       smtpd
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_relay_restrictions=permit_sasl_authenticated,reject
------------------------------------------------
```````````````````````````

4. 設定ファイル編集(postfix)
```````````````````````````
# vi /etc/postfix/main.cf
----------以下内容で編集------------------------
// ホスト名
myhostname = mail.hoge.com
mydomain = hoge.com
// ドメイン補完時の設定
myorigin = $mydomain

// hoge.comがメール宛先の最終目的地であることを認識させるため
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

inet_interfaces = all
inet_protocols = ipv4
// メール配送先(デフォルト設定)
home_mailbox = Maildir/

// SMTP認証有効
smtpd_sasl_auth_enable = yes
// postfixが、SMTP認証にDovecotSASLを使用する
smtpd_sasl_type = dovecot
// dovecot認証デーモンソケットのパスを指定する
smtpd_sasl_path = private/auth
// 古いバージョンのAUTHコマンドとの相互運用を有効
broken_sasl_auth_clients = yes

// 接続時の制限を指定
// 上から順に
// 認証に成功した場合のメール送信を許可
// このサーバで配送終了とならないドメイン宛メール送信を却下
// このサーバで配送終了となるドメイン宛メール送信を許可
// 接続元が$mynetworksにリストアップされたネットワーク・ホストから来たものであれば許可
smtpd_recipient_restrictions =
    permit_mynetworks
    permit_sasl_authenticated
    reject_unauth_destination
    permit_auth_destination

// 匿名ログインを許可しない
smtpd_sasl_security_options = noanonymous
------------------------------------------------

# postconf -n
# postfix check
# systemctl start postfix
# systemctl enable postfix
# systemctl status postfix

// /etc/以下にaliasesが存在しない場合、以下コマンドを実行する
# newaliases
// 以下状態になっている事
# ls /etc/aliases*
/etc/aliases  /etc/aliases.db
```````````````````````````

5. 設定ファイル編集(dovecot)
```````````````````````````
# vi /etc/dovecot/dovecot.conf
----------以下内容で編集-------------------------
// ipv4,ipv6を受け付ける
listen = *, ::
------------------------------------------------

# vi /etc/dovecot/conf.d/10-mail.conf
----------以下内容で編集-------------------------
// メールの保存形式と保存場所を設定する
mail_location = maildir:~/Maildir
------------------------------------------------

# vi /etc/dovecot/conf.d/10-master.conf
----------以下内容で編集-------------------------
// imap,pop3を有効化
inet_listener imap {
    port = 143
  }
inet_listener pop3 {
    port = 110
  }
// postfixでsmtp認証が出来るようにする
unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
------------------------------------------------

// 暗号化なし（smtp認証のみ）の場合、以下を実施する
# vi /etc/dovecot/conf.d/10-auth.conf
----------以下内容で編集-------------------------
// プレーンテキスト認証を許可
disable_plaintext_auth = no
// login認証を許可
auth_mechanisms = plain login
------------------------------------------------

# vi /etc/dovecot/conf.d/10-ssl.conf
----------以下内容で編集-------------------------
// ssl無効化
ssl = no
------------------------------------------------

# doveconf -n
# systemctl start dovecot
# systemctl enable dovecot
# systemctl status dovecot
```````````````````````````

6. maildir作成設定
```````````````````````````
// ユーザ追加時にMaildirが作成されるようにしておく
# mkdir /etc/skel/Maildir
# chmod 700 /etc/skel/Maildir
```````````````````````````

7. ユーザ作成とパスワード作成
```````````````````````````
# useradd -m -s /bin/bash hoge
// homeディレクトリ以下に、Maildirがある事
# ls -l /home/hoge/
// smtp認証に使うパスワード作成
# passwd hoge
// /etc/dovecot/conf.d/10-auth.confで、!include auth-system.conf.extとなっていれば、上記で作成したパスワードで認証する。
```````````````````````````

8. firewall許可
```````````````````````````````
# firewall-cmd --add-service=smtp --permanent
# firewall-cmd --add-service=smtp-submission --permanent
# firewall-cmd --add-service=pop3 --permanent
# firewall-cmd --add-service=imap --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
```````````````````````````````

9. mailテスト送信
```````````````````````````````
// ユーザ、パスの入力時にbase64形式が必要なため確認しておく
# echo -n "対象user" | base64
# echo -n "設定pass" | base64

//　対象SMTPサーバに587portでSMTP認証で接続する。local配送例のため、localhost指定
# telnet localhost 587
AUTH LOGIN
334 VXNlcm5hbWU6
bae64形式のユーザ名入力
334 UGFzc3dvcmQ6
bae64形式のパス入力
→235 2.7.0 Authentication successful と返る事

mail from:test@localhost
rcpt to:宛先ユーザ@localhost   ※宛先ユーザは作成したユーザ
data
-----本文入力------
testmail
.
-----本文入力終わり------
quit

// localhostではなく、hostsにドメイン書いてテスト送信する場合は以下作業をする
# vi /etc/hosts
------------------------------------------------
// テスト用ドメインをhostsに追記する
localIP 適当なドメイン
------------------------------------------------
# vi /etc/postfix/main.cf
------------------------------------------------
// テスト用ドメインもローカル配送と認識させる
mydestination = $myhostname, localhost.$myorigin, localhost, $myorigin, テスト用ドメイン
// nsswitch.conと同様にアドレス検索をする
smtp_host_lookup = native
------------------------------------------------
# systemctl restart postfix
```````````````````````````````

10. ログとメール確認
```````````````````````````````
// status=sent となっていること
# less /var/log/maillog
// 送信した内容のメールが届いていること
# vi /home/hoge/Maildir/new/smtp拡張子のファイル

※ログファイル自体存在しない場合、以下を実施
# systemctl status rsyslog
⇒起動していなければstart、サービスが無い場合は以下
※syslogまたはrsyslogが動いてないとログ記録されない
参照 https://wa3.i-3-i.info/word14296.html
# dnf install -y rsyslog
# systemctl start rsyslog
# systemctl enable rsyslog
# systemctl status rsyslog
再度テストメールを送って、/var/log/maillogを確認する
```````````````````````````````

11. 送ったメールをMUAからIMAP orPOP3で取得する
```````````````````````````````
// 検証でドメイン設定等がない場合は以下を実施する
// 対象メールサーバのipとホスト名確認
# ip a
# postconf -n | grep "myhostname"

// hostsに上記IPとホスト名を記載する
例
192.168.211.143 mail.hoge.com

// MUA(thunderbird,gmail等)の設定から、メール取得したいユーザ、ホスト名、パスを設定してアカウントを作る
例
アカウント hog@mail.hoge.com
パス smtp認証で使う上記ユーザのパス

// 後はIMAPかPOP3を選ぶ
```````````````````````````````

### 参照  

https://zenn.dev/hal_shu_sato/books/misskey-docker-compose-mail/viewer/dovecot
https://wiki.hgotoh.jp/documents/mail/mail-010
https://qiita.com/Kamonasu21c/items/ddafddcc7d4a0505a30f
https://www.server-memo.net/server-setting/postfix/almalinux9_postfix_smtp-auth_dovecot.html#toc9
https://www.rem-system.com/mail-postfix01/


---


## SMTP(Postfix)

■ 作業手順
全体設定参照
https://www.rem-system.com/mail-postfix01/


1. postfixインストール
```````````````````````````
# dnf install -y postfix
```````````````````````````

2. 設定ファイル編集と反映
```````````````````````````
# vi /etc/postfix/main.cf
※myhostname,mydomainで指定するドメインは、どこのdnsサーバにも存在してない
　架空のドメインでも良い模様。
[root@dbc56a3925ae ~]# dig smtp.hoge.com

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
// ホスト名
myhostname = smtp.hoge.com
mydomain = hoge.com
// envelopeFrom未指定の場合に付与するドメインを指定
// 例ではabc313232.com。myhostnameを指定すると、mail.abc313232.com
myorigin = $mydomain
// www.abc313232.comのようなサブドメインを、abc313232.comに統一する
masquerade_domains = hoge.com

// ★LAN内で他サーバから中継させるための必須追加設定★
// デフォルトは localhost のみになっているため、all にして他サーバからの接続を受け付ける
inet_interfaces = all
inet_protocols = ipv4
// このサーバ経由でメールを送っていいLANのネットワーク範囲（例）を指定する
mynetworks = 127.0.0.0/8, 192.168.3.0/24

# postconf -n
# postfix check
# systemctl start postfix
# systemctl enable postfix
# systemctl status postfix
```````````````````````````

3. firewall許可
```````````````````````````````
# firewall-cmd --add-service=smtp --permanent
# firewall-cmd --add-service=smtp-submission --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
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

//ログを確認してconnection refusedが出ている場合はOP25Bを疑う
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