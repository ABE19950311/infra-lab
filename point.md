https://docs.google.com/spreadsheets/d/1xLtSJK1TqNhlpQIzTS_1fI1Bpl9N0a-Lq9Ou4wOOZow/edit?gid=0#gid=0
https://drive.google.com/drive/folders/1dReiCwoGWndO48ufwKUVTwwdPjgn55B3
redmin cloud 本番環境構築


■serviceとsystemdのコマンド違い一覧
https://bacchi.me/linux/systemd-memo/

■localからフェイルオーバークラスタ組んだlbに対してリクエストする
コンテナ経由でフェイルオーバ用仮想IPにリクエストする
gateway用コンテナ立てて、そこから仮想IPに送る
一先ずlocal -> gateway間をssl化
例
server {
    listen 443 ssl;

    # ローカルに割り当たっているIP
    server_name 172.19.93.103;

    ssl_certificate /root/server.crt;
    ssl_certificate_key /root/server.key;

    # (オプション) セキュリティを少し強化する場合
    # ssl_protocols TLSv1.2 TLSv1.3;
    # ssl_prefer_server_ciphers on;

    # --- LBへの転送設定 ---
    location / {
        # ここにLBへのproxy_pass設定を記述します。
        # NGINX -> LB 間がHTTPなら http://
        # NGINX -> LB 間がHTTPSなら https://
        # フェイルオーバークラスタの仮想IP
        proxy_pass http://172.28.10.250;

        # 必要なヘッダー情報
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
}


■起動したvmwareesxiにブラウザからアクセスできない場合
→以下gemeni回答文。ブリッジ接続で上手くいかない場合はプロキシ等使ってないか確認する
Windows 11上のVMware Workstationで起動したESXiにブラウザからアクセスできない場合、原因のほとんどは仮想ネットワークの設定にあります。

ESXi VMがホストOS（Windows 11）や他の物理的なPCと同じネットワークに接続されていないため、通信ができていない状態です。

問題を解決するために、以下の手順を順番に確認してください。

1. VMware Workstationのネットワーク設定を確認する
最も可能性が高い原因です。ESXi仮想マシンのネットワークアダプタをブリッジモードに変更してください。

VMware WorkstationでESXiの仮想マシンを選択し、シャットダウンします。

「仮想マシン設定の編集」を開きます。

左側のリストから「ネットワーク アダプタ」を選択します。

右側の「ネットワーク接続」で、**「ブリッジ: 物理ネットワークに直接接続」**を選択します。

お使いのPCがWi-Fiでネットワークに接続している場合は、「構成」ボタンからWi-Fiアダプタが選択されていることを確認してください。有線LANの場合も同様です。

「OK」をクリックして設定を保存し、ESXi仮想マシンを起動します。

【なぜブリッジモードなのか？】
ブリッジモードにすると、ESXiの仮想マシンは、Windows 11のPCと同じルーターに接続された、独立した物理マシンのように振る舞います。これにより、ルーターのDHCPサーバーから直接IPアドレスが割り当てられ、同じネットワーク内の他のPCからアクセスできるようになります。

2. IPアドレスを確認する
ブリッジモードでESXiを再起動したら、コンソール画面（DCUI）に表示されるIPアドレスを再度確認します。

確認ポイント: 表示されているIPアドレスが、お使いのWindows 11 PCのIPアドレスと同じネットワークセグメントに属しているか確認してください。

例:

Windows 11 PCのIPアドレスが 192.168.1.10 の場合

ESXiのIPアドレスは 192.168.1.xx のようになっているはずです。

もし 169.254.x.x のようなアドレスになっている場合、DHCPサーバーからIPアドレスを正常に取得できていません。ESXiコンソール画面でネットワーク設定を見直すか、ルーターのDHCP機能を確認してください。

3. Windows 11のファイアウォールを確認する
次に考えられる原因は、ホストOSであるWindows 11のファイアウォールが通信をブロックしている可能性です。

切り分けのために、一時的にファイアウォールを無効にしてアクセスを試みてください。

Windowsの検索で「セキュリティ」と入力し、「Windows セキュリティ」を開きます。

「ファイアウォールとネットワーク保護」を選択します。

現在アクティブになっているネットワーク（通常はプライベートネットワーク）をクリックし、Microsoft Defender ファイアウォールをオフに切り替えます。

この状態で、ブラウザからESXiのIPアドレスにアクセスできるか試します。

もしこれでアクセスできた場合は、ファイアウォールが原因です。恒久的な対策として、特定の通信を許可するルールを追加してください。（テスト後は必ずファイアウォールを再度有効にしてください。）

4. ネットワークの疎通確認 (Ping)
基本的なネットワーク接続が確立しているかを確認します。

Windows 11でコマンドプロンプトまたはPowerShellを開きます。

以下のコマンドを実行します。（xx.xx.xx.xx はESXiのIPアドレスに置き換えてください）

ping xx.xx.xx.xx
「応答」や「Reply from...」というメッセージが返ってくれば、ネットワーク的には通信できています。この場合、ESXi側の管理サービスに問題がある可能性があります。

「要求がタイムアウトしました」や「宛先ホストに到達できません」と表示される場合は、やはりネットワーク設定（上記1〜3）に問題があります。

トラブルシューティングのまとめ
多くの場合、手順1のブリッジモードへの変更で解決します。まずはそこからお試しください。

それでも解決しない場合は、以下の順番で確認を進めてみてください。
ESXi VMのネットワーク設定を「ブリッジ」に変更する。
再起動後、ESXiに割り当てられたIPアドレスが適切か確認する。
Windows 11からESXiのIPアドレスへ ping が通るか確認する。
一時的にWindowsのファイアウォールを無効にしてアクセスを試す。
これらの手順で問題が特定できるはずです。

■dockerコンテナを起動させ続ける
https://qiita.com/sekitaka_1214/items/2af73d5dc56c6af8a167

■ディスク拡張時に確認する必要があるパーティションの仕様
https://www.hdd-tool.com/ja/disk-converter/convert-primary-partition-to-logical.html

■dockerで複数コンテナで同じport使う方法
ループバックインターフェース使う
https://blog.framinal.life/entry/2021/08/17/023028
ubuntuの場合は以下を使う
sudo ip addr add 127.0.0.2/8 dev lo

■windows11でwslとvmware workstationを両立させる
vmware workstationで対象仮想マシン設定で
「Intel VT-x/EPT または AMD-V/RVI を仮想化」チェック外す
https://qiita.com/matarillo/items/98d7452967987fe5d633

■ホスト情報一覧表示
abe@NPC-23-002:~$ hostnamectl status
 Static hostname: NPC-23-002
       Icon name: computer-container
         Chassis: container
      Machine ID: 6a0596464878419ab5ec4af268692e9c
         Boot ID: 93f9bc40993a411c8f3b230977c53a31
  Virtualization: wsl
Operating System: Ubuntu 22.04.4 LTS
          Kernel: Linux 6.6.87.2-microsoft-standard-WSL2
    Architecture: x86-64

■dockerでnfsサーバ構築時に以下エラー
exportfs: /nfs does not support NFS export
⇒nfsをサポートしてないファイルシステムになっている
[root@a36f0c06b11d ~]# df -T /nfs
Filesystem     Type     1K-blocks     Used Available Use% Mounted on
overlay        overlay 1055762868 19326600 982732796   2% /


■サーバ調査時に便利な呪文
https://www.digitalocean.com/community/tutorials/how-to-use-systemctl-to-manage-systemd-services-and-units-ja
apt list --installed
yum list installed
dnf list --installed
サーバでactiveになっているサービス一覧確認する
$ systemctl list-units -t service --no-pager

サーバに入ってる全サービス確認する
$ systemctl list-unit-files -t service --no-pager


■postfixで他サーバからメール送信する際にRelay access deniedが出る
https://tech-mmmm.blogspot.com/2018/03/postfix454-471-relay-access-denied.html
main.cfのmynetworksに送信元サーバからのIPを許可していなかった。

■ansibleでTypeError: 'NoneType' object is not iterable
中身空なのに定義していると発生する
---
- hosts: www
  become: true
  vars_files: ←中身全文コメントアウトしているのに定義しているためNG
    #- inventories/common/var.yml
    #- inventories/common/secret.yml
    #- inventories/dev/var.yml
  environment:
    http_proxy: "{{ http_proxy | default('') }}"
  roles:
    - common
    - base-alma
    #- nfsmount
    #- script-perl
    #- script-php
    #- application-settings
    - apache
    #- aws-cli

■ansible実行時のssh接続にパス聞かれて入れない
素直に対象サーバのユーザにパス設定する
$ sudo passwd 対象ユーザ

■ansibleの対象サーバにpython3があってpythonじゃない場合の対処
"/bin/sh: /usr/bin/python: No such file or directory\r\n",
https://dev.classmethod.jp/articles/ansible-python3/
実行コマンドに-e 'ansible_python_interpreter=/usr/bin/python3'を入れる



systecmtlない
⇒systemd対応してないイメージ使ってるため
⇒対応しているイメージ使う

基本的なlinuxコマンドがコンテナにない
⇒build時にdnf,yum等で入れる

System has not been booted with systemd as init system (PID 1). Can't operate.
Failed to connect to bus: Host is down
⇒https://zenn.dev/ippe1/articles/327f2b1ed423cb


コンテナのIP固定したい
⇒https://zaki-hmkc.hatenablog.com/entry/2021/02/26/234357

ブラウザからコンテナapacheリクエスト
⇒https://zenn.dev/hiddy0329/articles/822aa3f0903f3f

別サーバAPとの連携
⇒https://qiita.com/Hiraku/items/60ef1ff9801fa9945d43

php-fpm起動しても9000portで待ち受けない
⇒/etc/php-fpm.d/www.confで以下記述を変える
; listen = /run/php-fpm/www.sock
　　　　　↓
listen = 0.0.0.0:9000

apacheからphp-fpm疎通とれない
 apへのping,ncでのport確認問題ないのにだめ
 nc -zv 172.28.10.3 9000
理由 Connection reset by peer
/etc/php-fpm.d/www.confで、デフォルトだとローカルからしか受け付けてなかった
webサーバのIPを受け付けるように変更
; listen.allowed_clients = 127.0.0.1
listen.allowed_clients = 172.28.10.2
https://qiita.com/ko-suke2020/items/dd7468d6f8f1010e85bd

apからdbに接続できない
Host 'ap.create_server_custom_net' is not allowed to connect to this MySQL server
⇒ユーザにアクセス権がないため。GRANT ALL PRIVILEGES
https://zenn.dev/ryo_kawamata/articles/mysql-connect-error

nagios初期構築
https://www.unix-power.net/networking/post-616
　nagios入れたら/etc/httpd/conf.d/nagios.conf が出来る
　httpとnagios起動
　→includeで/etc/httpd/conf.d/nagios.conf読む
　→Alias /nagios "/usr/share/nagios/html"より、/nagiosでindex読みにに行く
  →basic認証用にhtpasswd設定しておく

nagios設定追加関連
https://www.unix-power.net/networking/post-616
 Invalid max_check_attempts value for host
 https://blog.goo.ne.jp/hasebennki/e/d7816edbfcf8c242eefb787d6910d030
 /etc/nagios/nagios.cfgに以下追加
 # 追記
cfg_file=/etc/nagios/objects/services.cfg
cfg_file=/etc/nagios/objects/hosts.cfg
[root@9ffbac8147cb objects]# cat hosts.cfg
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
[root@9ffbac8147cb objects]# cat services.cfg
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

pacemaker+corosyncとは
https://www.tohoho-web.com/ex/pacemaker.html#:~:text=Pacemaker%2FHeartbeat%2FCorosync%20%E3%81%AF%20Linux,%E8%80%90%E6%95%85%E9%9A%9C%E6%80%A7%E3%82%92%E9%AB%98%E3%82%81%E3%81%BE%E3%81%99%E3%80%82
https://www.designet.co.jp/ossinfo/ha-cluster/corosync/


・innodbクラスタ関連
 innodbクラスタの構成はmysqlshで。実施場所はmysqlrouterサーバ






## sshできないとき
現象１．WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
⇒対象ホストが何らかの理由(autoscale)で変わったら発生する
  known_hostsから対象ホストを削除する
$ ssh-keygen -R ホスト
https://qiita.com/nanbuwks/items/47248b6ed2d37086e40d


## Dockerで停止しているコンテナに入る
https://zenn.dev/sinozu/articles/8c51091af73cd1b386b8


## ProxyCommand
https://neos21.net/blog/2019/11/08-01.html

setumei
ProxyCommand -W %h:%p は、OpenSSHの機能であり、SSHトンネリングを設定する際に使用されます。ProxyCommandは、SSHクライアントが他のホストを経由して接続するためのコマンドを指定します。-W %h:%p の部分は、ProxyCommandが実行された際に利用されるコマンドです。

具体的には、%h は接続先のホスト名を、%p はポート番号を表します。-W オプションは、SSHがバージョン7.3以降でサポートされています。このオプションを使用することで、SSHクライアントが指定したホストとポートへの接続を確立するために、指定されたコマンドが実行されます。

例えば、ProxyCommandを使ってSSHクライアントが内部ネットワークのサーバーにアクセスする場合、以下のように設定します。

perl
Copy code
Host internal-server
    ProxyCommand ssh -W %h:%p gateway.example.com
この場合、SSHクライアントは internal-server に接続しようとすると、まず gateway.example.com に接続し、そこから internal-server にトンネルを作成します。そして、-W %h:%p によって、SSHクライアントは internal-server に直接接続できます。

この方法は、ジャンプホスト（バスジャンプ）を介して内部ネットワークにアクセスする際に便利です。


## ■エラー関連総合
* UbuntuでFailed to fetch 404 Not Found
https://www.linuxmaster.jp/linux_blog/2022/02/ubuntu2004failed-to-fetch-404-not-found.html

* System has not been booted with systemd as init system (PID 1). Can't operate. Failed to connect to bus: Host is down
https://snowsystem.net/other/windows/wsl2-ubuntu-systemctl/

* SSH接続エラー【PAM】（error: Could not get shadow information for user）
https://www.goritarou.com/?p=1616


## 他解決に至った問題
* redis起動時のFailed to start Advanced key-value store.
** /var/log/redis/redis-server.logを確認した
** # Warning: Could not create server TCP listening socket 127.0.0.1:6379: bind: Address already in useが発生していた
* laravelDomPdfで画像が透明になる
** ImageMagicライブラリが7系だったことが原因。6系に導入し直したことで解決
* mysql,mariadb,redis,nginx等のMWに外部接続できない
** SELinuxが有効になっていた
→/etc/selinux/configでSELINUX=enforcingをSELINUX=disabledに変更してサーバ再起動
** ファイアウォール、セキュリティグループで対象ポートを解放していなかった
** MWの設定で外部接続を有効にしていなかった
→各ポートのListen状況はssコマンド等で確認できる
https://blog.mothule.com/ruby/rails/active-record/ruby-rails-active-record-separate-rails-and-db
https://office54.net/iot/database/mariadb-external-access


* IP固定は/etc/sysconfig/network-scripts/ifcfg-インターフェース名
NetworkManagerが動いているならnmcli
無い場合は手動修正、また、NM_CONTROLLED等の設定値は動かない


* route設定は/etc/sysconfig/network-scripts/route-インターフェース名

* 特に前触れなくnagios監視サーバから全対象のアラーム発砲
→対象サーバでnrpe動いているか？サービスdisableになっていて再起動後起動していなかった等


* サーバ調査で調べたいこと
・OS
$ cat /etc/redhat-release
$ hostnamectl status
等
・サービス一覧
$ systemctl list-units -t service --no-pager
→動いてるサービス確認
$ systemctl list-unit-files -t service --no-pager | grep "disable"
→disableになってるけど本来動いてないといけないサービス混ざってないか
・上で調べたサービスのバージョン確認
$ mysql --version
$ nginx -v
$ php -v
$ yum list installed | grep "サービス名"
$ $ postconf | grep "mail_version" 
等
・各サービスの設定値
$ cat /etc/my.cnf
$ cat /etc/nginx/nginx.conf
等
・phpあるならモジュール
$ php -m
・プロセス
$ ps axjf
・cron
# ls -l /var/spool/cron/
・/tmp









## リクエストデコードするコマンド
echo "URL" | python3 -c "import sys, urllib.parse; print(urllib.parse
.unquote(sys.stdin.read().strip()))"

isoをproxmoxアップロード時に error 0 occurred while receiving the documentが発生するため、sshでproxmoxに入って、元々あったisoをマウント先のnas04の所定ディレクトリにコピーした

nmcli con mod ens18 ipv4.addresses "172.16.127.220/24"

default via 172.16.0.1 dev vmbr0.200 proto kernel onlink
172.16.0.0/16 dev vmbr0.200 proto kernel scope link src 172.16.0.114


既存のproxmoxのip rより172.16.0.0/16ネットワークだった
nmcliで172.16.0.0/16の範囲でipv4とdefault gateway設定
nmcliでmethodがautoだったのを手動設定のmanualに変更
nmcliでインターフェース再起動


defaultゲートウェイに172.16.0.1を設定してもping通らない
vlanタグを使う
ネットデバイス
linux vlanを使う
vlan tag 200を設定
ping通るようになった
そのため、原因はvlanタグの設定がなかったこと



・elastcisearch
0.ユーザ作成
useradd -m elastic
1.elastciユーザでtar.gz解凍。tarが無い場合はpython3で出来る
rootユーザだと出来ないとこのこと
https://qiita.com/KI1208/items/991b5cb29e8d4b790101
2.elastcisearc/config/elasticsearch.ymlに外部接続許可設定追加する
https://qiita.com/fuku2014/items/c2e2ffc07da5e2d2ba05
*transport.tcp.portはtransport.portにする
3.elastisearch/bin/elaticsearchで実行する(ssl関連は初期でconfig/certsに存在する)
4.curl --cacert elasticsearch-9.0.1/config/certs/http_ca.crt -u elastic:<PassWord> https://localhost:9200 で動作確認。パスワードは3実行時にコンソールにパスとトークンがはかれる
5.bin/elasticsearch -d -p /tmp/elasticsearch.pidでバックグラウンド実行
https://document.intra-mart.jp/library/bpm/public/im_bpm_setup_guide/texts/elasticsearch/start-stop/index.html
止めるときは下記
cat /tmp/elasticsearch.pid
kill pid番号

・logstash
１．テスト用のログをどこかに作成。中身は"Hello Logstash!"
２．ログを読み取るテスト用conf作成して実行
bin/logstash -r -f "/home/elastic/logstash-9.0.1/config/modsec.conf"
https://www.elastic.co/jp/blog/a-practical-introduction-to-logstash


・kibana
1.config/kibana.ymlで下記行のコメントアウト解除する
elasticsearch.hosts: ["http://localhost:9200"]
　また、下記行の記述を変える
server.host: "localhost"
　　　　　↓
server.host: "172.16.127.220"（固定したproxmoxのIP）

pid.file: /tmp/kibana.pid
２．kibanaを起動する
bin/kibana
コンソールにはきだすＵＲＬにブラウザからアクセスする
３．日本語化
https://zenn.dev/kyami/articles/417468a3517f1a
4．kibanaバックグラウンド実行(初期起動は少し時間がかかる、ポートの多重使用注意)
nohup bin/kibana > /dev/null 2>&1 &


kibana当で使うトークンの再発行
https://qiita.com/nfwork01/items/0f36305bed35d7d8bb98#%E3%83%88%E3%83%BC%E3%82%AF%E3%83%B3%E3%81%AE%E5%86%8D%E7%99%BA%E8%A1%8C%E3%81%A8kibana%E3%81%AE%E5%88%9D%E6%9C%9F%E8%A8%AD%E5%AE%9A


logstash設定例
https://www.elastic.co/jp/blog/a-practical-introduction-to-logstash
https://www.elastic.co/docs/reference/logstash
https://amateur-engineer-blog.com/getting-started-logstash-configuration
 moderead
https://qiita.com/nskydiving/items/0cb598de7ffb5c22424d

modsecurity概要
https://www.tohoho-web.com/ex/modsecurity.html

logstashのログ出力しない
　既に読み込んだから→since_dbpath nullにする

フィールドあるはずなのに読み込まれない
　データの検索範囲を見直す

logstah.ymlでpipeline.workers: 1 にする

トランザクションごとにフィールドまとまらない問題
・push_map_as_event_on_timeout trueにした
・下記からmap.clear消した
if event.get("rule_id")
        map["rule_id"] ||= []
        map["rule_id"] |= event.get("rule_id")
      else
        map.delete("rule_id")
      end

      map.each { |k, v| event.set(k, v) }
      map.clear
      else
          event.cancel
    end

modsecログ構成
https://github.com/owasp-modsecurity/ModSecurity/wiki/ModSecurity-2-Data-Formats

特定のログ指定
https://discuss.elastic.co/t/logstash/200780

kibana
・messageからKQLで特定の値含んでるかフィルター（検索）はできるが、データの抽出はできなさそう
・表

proxmox検証環境の時間少しずれてる



・トランザクションID毎にセクションZのタイミングでデータ集約して出力できていること
・rule_idはHセクションのmessageで出力している物だけが紐づいていること（他トランザクションのデータが紛れてないこと）




kibanaで取り込んでいるはずのデータが表示されない
→elasticsearch->インデックス->キャッシュ削除、およびフラッシュ->インデックスクリック->discover
→データ取り込まれていない、または全てバッファにいっていたというより、変なキャッシュ等が残っていたのが原因と思われる


kibanaバッファ出力する
→logstash.ymlでqueue.type: persisted
logstashでqueue.type: persistedにすると/path/to/logstash/data/queueにデータが残って
inputに指定していないデータが出力されるため、memoryにする。
変にデータ残った場合はrm -rf /path/to/logstash/data/queue/*


sectionフィールドを出力しないと、各セクション時のフィールド格納処理等が動かなくなるため、出力する

pass,token 出力例
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ Elasticsearch security features have been automatically configured!
✅ Authentication is enabled and cluster connections are encrypted.

ℹ️  Password for the elastic user (reset with `bin/elasticsearch-reset-password -u elastic`):
  Tn1gekSHh_Tq0mf=8Dox

ℹ️  HTTP CA certificate SHA-256 fingerprint:
  2d4df65ad2498e7a45b05902eb4872a7aff23c744502a96d30d212433037175c

ℹ️  Configure Kibana to use this cluster:
• Run Kibana and click the configuration link in the terminal when Kibana starts.
• Copy the following enrollment token and paste it into Kibana in your browser (valid for the next 30 minutes):
  eyJ2ZXIiOiI4LjE0LjAiLCJhZHIiOlsiMTcyLjE2LjEyNy4yMjA6OTIwMCJdLCJmZ3IiOiIyZDRkZjY1YWQyNDk4ZTdhNDViMDU5MDJlYjQ4NzJhN2FmZjIzYzc0NDUwMmE5NmQzMGQyMTI0MzMwMzcxNzVjIiwia2V5IjoiaV90Q3c1WUJLMktDQng3TzdYQkg6a0hpRTk3NzE2TXVrNW5BQURYMV9NUSJ9

ℹ️  Configure other nodes to join this cluster:
• On this node:
  ⁃ Create an enrollment token with `bin/elasticsearch-create-enrollment-token -s node`.
  ⁃ Uncomment the transport.host setting at the end of config/elasticsearch.yml.
  ⁃ Restart Elasticsearch.
• On other nodes:
  ⁃ Start Elasticsearch with `bin/elasticsearch --enrollment-token <token>`, using the enrollment token that you generated.




  template 反映されない原因と対処
  ありがとうございます。logstash.conf の設定を確認しました。テンプレートが反映されない原因として、以下の明確なポイントが見つかりました。

❗原因：template オプションは非推奨かつ無効
ruby
コピーする
編集する
elasticsearch {
  ...
  template => "/home/elastic/custom_template.json"
}
これは 古い Logstash 5.x 系の構文で、Logstash 7.x 以降では template オプションは廃止されており、無視されます。

✅ 解決策：テンプレートは Kibana Dev Tools や curl で明示的に登録
Logstashではなく、Elasticsearch APIを直接使ってテンプレートを登録してください。

1. テンプレートを REST API 経由で登録
以下のように curl でテンプレートを登録します：

bash
コピーする
編集する
curl -u elastic -k -X PUT "https://localhost:9200/_index_template/test_template" \
-H "Content-Type: application/json" \
--cacert /home/elastic/elasticsearch-9.0.1/config/certs/http_ca.crt \
-d @/home/elastic/custom_template.json
または中身をそのまま送信：

bash
コピーする
編集する
curl -u elastic -k -X PUT "https://localhost:9200/_index_template/test_template" \
-H "Content-Type: application/json" \
--cacert /home/elastic/elasticsearch-9.0.1/config/certs/http_ca.crt \
-d '{
  "index_patterns": ["test*"],
  "template": {
    "mappings": {
      "properties": {
        "message_a": {
          "type": "text",
          "fields": {
            "keyword": {
              "type": "keyword",
              "ignore_above": 32766
            }
          }
        },
        "message_b": { ... },
        "message_c": { ... },
        "message_f": { ... },
        "message_h": { ... }
      }
    }
  }
}'
※ index_patterns は "test_index" にマッチするように "test*" としてください。

✅ Logstash 側の修正
テンプレートをLogstash経由で登録しないようにし、Elasticsearch APIで登録したテンプレートが適用されるように設定します。

ruby
コピーする
編集する
elasticsearch {
  hosts => ["https://localhost:9200"]
  user => "elastic"
  password => "Tn1gekSHh_Tq0mf=8Dox"
  ssl_certificate_authorities => ["/home/elastic/elasticsearch-9.0.1/config/certs/http_ca.crt"]
  index => "test_index"
  manage_template => false  # これを明示的に指定
}
✅ インデックスの再作成が必要
既に作成済みの test_index にはテンプレートは適用されません。テンプレートを適用したければ、新しいインデックスを作成する必要があります。

たとえば：

ruby
コピーする
編集する
index => "test_index_v2"
テンプレートが "test*" にマッチしていれば、test_index_v2 にも適用されます。

✅ 動作確認の手順（推奨）
既存の test_index を削除（必要に応じて）。

テンプレートを上記 curl で登録。

Logstash の出力インデックス名を test_index_v2 に変更。

Logstash 再実行。

GET test_index_v2/_mapping でマッピングを確認。

ご希望があれば、テンプレート登録用の curl コマンドの雛形もファイル形式でご提供できます。必要であればお知らせくださ


5/28
[root@localhost ~]# df -h
Filesystem                  Size  Used Avail Use% Mounted on
devtmpfs                    4.0M     0  4.0M   0% /dev
tmpfs                        32G     0   32G   0% /dev/shm
tmpfs                        13G  8.6M   13G   1% /run
/dev/mapper/almalinux-root   70G  1.7G   69G   3% /
/dev/mapper/almalinux-home  398G   17G  381G   5% /home
/dev/sda1                   960M  230M  731M  24% /boot
tmpfs                       6.3G     0  6.3G   0% /run/user/0

・目的 
誤検知となるruleを除外し、modsecurityを全cartに対し適用する

・経緯
以前modsecurity導入時に誤検知発生
原因は、set8のログは確認していたが他setのログを確認していなかった
他setのログを確認する際量が膨大
そのため、elk-stack環境を構築して確認効率を上げる
約１か月分のデータを対象にする。メモリとCPUに問題がないか確認する
現設定で検知したruleを洗い出し、検知理由と理由に関わるデータを確認し、誤検知になり得るか確認する

・現状
４日分のデータ投入して調査中。
CPU,メモリ、ディスク容量に問題はない
top - 12:46:47 up 20 days, 20:47,  2 users,  load average: 1.57, 1.57, 1.06
Tasks: 210 total,   1 running, 209 sleeping,   0 stopped,   0 zombie
%Cpu(s): 11.8 us,  0.7 sy,  0.0 ni, 86.8 id,  0.1 wa,  0.3 hi,  0.1 si,  0.0 st
MiB Mem :  63789.7 total,    574.6 free,  36994.5 used,  26944.7 buff/cache
MiB Swap:  32216.0 total,  32215.7 free,      0.3 used.  26795.2 avail Mem

[elk@localhost ~]$ df -h
Filesystem                  Size  Used Avail Use% Mounted on
devtmpfs                    4.0M     0  4.0M   0% /dev
tmpfs                        32G     0   32G   0% /dev/shm
tmpfs                        13G   17M   13G   1% /run
/dev/mapper/almalinux-root   70G  2.7G   68G   4% /
/dev/mapper/almalinux-home  398G   43G  355G  11% /home
/dev/sda1                   960M  230M  731M  24% /boot
tmpfs                       6.3G     0  6.3G   0% /run/user/0

検知したrule一覧と内容にについてスプレッドシートにまとめて、レビュー可能な状態に整理する

・現在の課題
特になし


■ratelimitセキュリティチューニング(fortigate)
・閾値調整のため、モニタ設定
・IPSシグネチャ作成
・特定のサーバへのリクエストを対象にしたい
→対象サーバをまとめたアドレスグループを作成。
上記グループ対象の新規ＦＷポリシーとＩＰＳセンサーを作成
作成したＩＰＳセンサーに対してＩＰＳシグネチャを適用
defaultIPSセンサーだと他サーバへのリクエストも対象にするため
・自社保有ＩＰのブロックを防ぐため、対象ＩＰを資料等から洗いだして除外設定
・モニタ設定と検知状況基に隔離設定を実施

■ip reputation(fortigate)
レベル１～５で分かれている
レベル１が悪質、レベル３が未認証、レベル５が安全と判断している
defaultは値０に設定されている。例として値３で設定すれば、１～３に含まれるIP全てブロックする
レベル１の時点でgooglebot等が含まれており、ページランクへの影響を懸念して対応は見送った


