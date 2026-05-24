■ 作業手順

1. httpd,nagiosインストール
`````````````````````````````````
# EPELリポジトリのインストール
# dnf install -y epel-release

# パッケージのインストール
# dnf config-manager --set-enabled crb
# dnf install -y httpd nagios nagios-plugins-all nagios-plugins-nrpe
`````````````````````````````````

2. basic認証初期設定
`````````````````````````````````
# Web UI用のBasic認証初期設定
# htpasswd -c /etc/nagios/passwd nagiosadmin

# httpdの起動と自動起動有効化
# systemctl start httpd
# systemctl enable httpd
`````````````````````````````````

3. ファイアウォール許可,selinux無効
`````````````````````````````````
# firewall-cmd --add-service=http --permanent
# firewall-cmd --reload
# firewall-cmd --list-all

# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
`````````````````````````````````

3. nagiosに読み込ませる設定ファイル追加
`````````````````````````````````
# vi /etc/nagios/nagios.cfg
-----------以下を追記(ファイル名は方針による)----------------
cfg_file=/etc/nagios/objects/services.cfg
cfg_file=/etc/nagios/objects/hosts.cfg
`````````````````````````````````

4. 最低限の監視追加
`````````````````````````````````
# vi /etc/nagios/objects/services.cfg
-----------以下を追記----------------
define service {
    use                     generic-service
    host_name               web
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}
define service {
    use                     generic-service
    host_name               ap
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}
define service {
    use                     generic-service
    host_name               db
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}

# vi /etc/nagios/objects/hosts.cfg
-----------以下を追記----------------
define host{
   use       linux-server
   host_name web
   address   172.28.10.2
}
define host{
   use       linux-server
   host_name ap
   address   172.28.10.3
}
define host{
   use       linux-server
   host_name db
   address   172.28.10.4
}

# 設定ファイルにエラーがないかテストする（エラーが0であることを確認）
# nagios -v /etc/nagios/nagios.cfg

# Nagiosの起動と自動起動有効化
# systemctl start nagios
# systemctl enable nagios
# systemctl status nagios
`````````````````````````````````

5. hostgroupsに一覧表示する
`````````````````````````````````
# vi /etc/nagios/objects/hosts.cfg
------------以下を追加-------------
define hostgroup {
    hostgroup_name  my-system-servers  ; グループの内部名（英数字やハイフンなど）
    alias           My System Servers  ; Web UIの画面上に表示される見出し名
    members         web, \
                    ap, \
                    db          ; グループに所属させるホスト名（カンマ区切り）
}

# nagios -v /etc/nagios/nagios.cfg
# systemctl restart nagios
`````````````````````````````````

--------------------------------------------------------------------

■nrpe導入
nagiso監視対象サーバで実施する

1. 【監視対象サーバー側】 NRPEとプラグインのインストール
`````````````````````````````````
監視対象となるすべてのサーバー（web, ap, db）で以下の作業を行う

# EPELリポジトリのインストール
# dnf install -y epel-release

// NRPEデーモンとNagiosプラグインのインストール
# dnf config-manager --set-enabled crb
# dnf install -y nrpe nagios-plugins-all
`````````````````````````````````

2. 【監視対象サーバー側】 NRPEの設定
`````````````````````````````````
Nagiosサーバーからの通信を許可し、監視コマンドを定義。

# vi /etc/nagios/nrpe.cfg
-----------以下の箇所を変更・追記----------------
# 許可するIPアドレスにNagiosサーバーのIPを追加（例: 172.28.10.1 の場合）
allowed_hosts=127.0.0.1,::1,172.28.10.1
# 2. 引数渡しを許可 (0 から 1 に変更)
dont_blame_nrpe=1
# ==========================================
# 1. 基本のリソース監視（全サーバー共通）
# ==========================================
# CPU負荷 (警告: 1.5, 異常: 3.0)
command[check_load]=/usr/lib64/nagios/plugins/check_load -r -w 1.5,1.0,0.5 -c 3.0,2.5,2.0

# ディスク使用量 (ルートディレクトリの空き容量が 20% で警告、10% で異常)
command[check_disk]=/usr/lib64/nagios/plugins/check_disk -w 20% -c 10% -p /

# Swap使用量 (空きが 20% で警告、10% で異常)
command[check_swap]=/usr/lib64/nagios/plugins/check_swap -w 20% -c 10%

# ゾンビプロセス数 (5個で警告、10個で異常)
command[check_zombie_procs]=/usr/lib64/nagios/plugins/check_procs -w 5 -c 10 -s Z

# ==========================================
# 2. 個別プロセス監視用（引数を受け取る汎用コマンド）
# ==========================================
# Nagiosサーバーから「閾値($ARG1$)」と「プロセス名($ARG2$)」を受け取って実行する
command[check_procs_args]=/usr/lib64/nagios/plugins/check_procs -c $ARG1$ -C $ARG2$
`````````````````````````````````

3. 【監視対象サーバー側】 NRPEの起動とファイアウォール設定
`````````````````````````````````
# NRPEの起動と自動起動有効化
# systemctl start nrpe
# systemctl enable nrpe

# ファイアウォールで5666番ポートを許可
# firewall-cmd --add-port=5666/tcp --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
`````````````````````````````````

4. 【Nagiosサーバー側】 通信テスト
`````````````````````````````````
Nagiosサーバーから監視対象へアクセスできるか確認。

// Nagiosサーバー上で実行（監視対象が 172.28.10.2 の場合）
# /usr/lib64/nagios/plugins/check_nrpe -H 172.28.10.2

// 成功するとNRPEのバージョンが返る
NRPE v4.1.x
`````````````````````````````````

5. コマンド定義（引数付きNRPEコマンドの作成）
`````````````````````````````````
# vi /etc/nagios/objects/commands.cfg
-----------ファイル末尾に以下を追記----------------
# 標準の check_nrpe コマンドの定義
define command {
    command_name    check_nrpe
    command_line    $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
}
define command {
    command_name    check_nrpe_args
    command_line    $USER1$/check_nrpe -H $HOSTADDRESS$ -c $ARG1$ -a $ARG2$ $ARG3$
}
`````````````````````````````````

6. サービス（監視項目）の定義
`````````````````````````````````
# vi /etc/nagios/objects/services.cfg
-----------以下を追記----------------
# --- グループ全体への共通監視 ---
# PING監視
define service {
    use                     generic-service
    hostgroup_name          my-system-servers
    service_description     PING
    check_command           check_ping!100.0,20%!500.0,60%
}
# CPU負荷
define service {
    use                     generic-service
    hostgroup_name          my-system-servers
    service_description     CPU Load
    check_command           check_nrpe!check_load
}
# ディスク空き容量 (ルートパーティション)
define service {
    use                     generic-service
    hostgroup_name          my-system-servers
    service_description     Disk Space
    check_command           check_nrpe!check_disk
}

# --- 各サーバー個別のプロセス監視 ---
# Webサーバーの httpd プロセス監視
define service {
    use                     generic-service
    host_name               web
    service_description     Process: httpd
    check_command           check_nrpe_args!check_procs_args!1:!httpd
}
# DBサーバーの mysqld プロセス監視
define service {
    use                     generic-service
    host_name               db
    service_description     Process: mysqld
    check_command           check_nrpe_args!check_procs_args!1:!mysqld
}

# nagios -v /etc/nagios/nagios.cfg
# systemctl restart nagios
`````````````````````````````````

-------------------------------------------------

■アラートメール通知

1. 【Nagiosサーバー側】 送信テストとPostfixの起動
Nagios自身はメールを送信するエンジンを持っておらず、OSの mail コマンドに宛先と本文を渡して「あとはよろしく！」と丸投げしています。
もしNagiosから外部SMTPへ直接送る設定にしてしまうと、ネットワークの瞬断等で一瞬でも外部SMTPと通信できなかった場合、そのアラートメールは永遠に失われてしまいます。

間にローカルのPostfixを挟んでおけば、Postfixが「外部SMTPと通信できなかったから、5分後に再送しよう」とキュー（送信待ち行列）に溜めて自動で再試行してくれるため、監視のアラートを取りこぼすリスクが激減します。
`````````````````````````````````
まずはNagiosサーバーからメールが送信できる状態を作ります。RHEL9系では通常 postfix が標準のメール送信プログラム（MTA）として動きます。

# postfixとメール送信コマンドのインストール（入っていない場合）
# dnf install -y postfix
外部SMTPでID/パスワード認証（SASL認証）を行うために必要なパッケージを入れます。
# dnf install -y cyrus-sasl-plain

# postfixの起動と自動起動有効化
# systemctl start postfix
# systemctl enable postfix

# 【重要】実際にメールが届くかコマンドラインからテスト
# echo "Nagios Test Mail" | mail -s "Test" your-email@example.com
※ your-email@example.com を、実際にあなたが受信できるメールアドレスに書き換えて実行してください。もし届かない場合は、社内ネットワークのファイアウォールやプロバイダの25番ポートブロック（OP25B）、メールサーバー側の受信拒否（迷惑メールフォルダ）などを確認する必要があります。
`````````````````````````````````

2. Postfixのメイン設定ファイル（main.cf）を編集する
`````````````````````````````````
すべてのメールを外部SMTPへリレーするように設定を追記します。
# vi /etc/postfix/main.cf
ファイルの末尾に以下を追記してください。
# --- 外部SMTPリレー設定 ---
# リレー先のSMTPサーバーとポートを指定
relayhost = [ip or domain]:25
`````````````````````````````````

4. 設定の反映とテスト送信
`````````````````````````````````
Postfixを再起動して設定を読み込ませます。

Bash

# systemctl restart postfix
この状態で、前回と同じテストコマンドを実行してみてください。

Bash

# echo "Relay Test Mail" | mail -s "Test" your-email@example.com
`````````````````````````````````

2. 【Nagiosサーバー側】 通知先（連絡先）の設定
`````````````````````````````````
メールが届くことが確認できたら、Nagiosに「誰にメールを送るか」を設定します。標準の連絡先設定ファイル（contacts.cfg）を編集します。

# vi /etc/nagios/objects/contacts.cfg
define contact ブロックを探し、email の部分をあなたのメールアドレスに書き換えます。

Plaintext

define contact {
    contact_name            nagiosadmin             ; 連絡先名
    use                     generic-contact         ; テンプレートの適用
    alias                   Nagios Admin
    email                   your-email@example.com  ; ←★ここに通知先のメールアドレスを記載
}
`````````````````````````````````

3. 【Nagiosサーバー側】 監視項目への通知設定（CRITICALのみ）
`````````````````````````````````
# vi /etc/nagios/objects/services.cfg

ファイルの一番上に「自作テンプレート」を定義する
ファイルの先頭付近に、以下のブロックを追記します。

# --- 自分専用のアラート設定入りテンプレート ---
define service {
    name                    my-alert-service
    use                     generic-service
    contacts                nagiosadmin
    
    # ↓復旧[r]、異常[c]を小文字・スペースなしで明記
    notification_options    c,r
    
    # ↓【追記】通知を行う時間帯（24時間いつでも）
    notification_period     24x7
    
    # ↓【追記】通知を有効にする（親の設定を強制上書き）
    notifications_enabled   1
    
    register                0
}
※ register 0 がNagiosにおける「これはテンプレートですよ」という宣言になります。

3. 各監視項目の use を書き換え、不要な行を消す
あとは、各監視項目の設定を以下のようにスッキリさせます。use の部分を今作ったテンプレート名に変更し、個別に書いていた contacts などの行はすべて削除してOKです。

Plaintext

# CPU負荷監視
define service {
    use                     my-alert-service      ; ←★先ほど作ったテンプレートを指定
    hostgroup_name          my-system-servers
    service_description     CPU Load
    check_command           check_nrpe!check_load
}

# ディスク使用量監視
define service {
    use                     my-alert-service      ; ←★ここも同じ
    hostgroup_name          my-system-servers
    service_description     Disk Space
    check_command           check_nrpe!check_disk
}

# (他のプロセス監視なども同様に use my-alert-service に書き換え、通知設定の2行を消します)
`````````````````````````````````

4. 設定の反映
`````````````````````````````````
すべての編集が終わったら、構文チェックをしてNagiosを再起動します。

Bash

# 構文チェック（Errorが0であることを確認）
# nagios -v /etc/nagios/nagios.cfg

# Nagiosの再起動
# systemctl restart nagios
`````````````````````````````````

-----------------------------------------

■カスタムスクリプトで監視する場合