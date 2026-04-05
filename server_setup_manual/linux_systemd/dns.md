■ 作業手順

1. bind,bind-chrootインストール
`````````````````````````````````````
# dnf install -y bind bind-chroot
# systemctl start named-chroot-setup
# systemctl status named-chroot-setup
# systemctl enable named-chroot-setup
⇒/以下の各namedサービスファイルと/var/named/chroot/配下とのmountを生成する
`````````````````````````````````````

2. named.conf修正
``````````````````````````````````````
// chroot配下ではなくetc配下を編集する
# vi /etc/named.conf
※forward only,forwareders入れてる理由
https://blue-red.ddo.jp/~ao/wiki/wiki.cgi?page=DNS%A5%B5%A1%BC%A5%D0%A1%BC%A4%CE%C0%DF%C4%EA
-----------以下内容で修正する----------
options {
	listen-on port 53 { dnsサーバインターフェースIP; }; ★
	listen-on-v6 port 53 { ::1; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	secroots-file	"/var/named/data/named.secroots";
	recursing-file	"/var/named/data/named.recursing";
	allow-query     { localhost; 許可するIPとCIDR; };　　　★

	/* 
	 - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
	 - If you are building a RECURSIVE (caching) DNS server, you need to enable 
	   recursion. 
	 - If your recursive DNS server has a public IP address, you MUST enable access 
	   control to limit queries to your legitimate users. Failing to do so will
	   cause your server to become part of large scale DNS amplification 
	   attacks. Implementing BCP38 within your network would greatly
	   reduce such attack surface 
	*/
	recursion yes;

	dnssec-validation yes;

        forward only;　　　　　　　　　　　★
        forwarders { dnsサーバIP; };　　★

	managed-keys-directory "/var/named/dynamic";
	geoip-directory "/usr/share/GeoIP";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";

	/* https://fedoraproject.org/wiki/Changes/CryptoPolicy */
	include "/etc/crypto-policies/back-ends/bind.config";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
	type hint;
	file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
include "/etc/named/record.conf";    ★
``````````````````````````````````````

3. test用record作成
``````````````````````````````````````
# vi /etc/named/record.conf
-----------以下を追記-----------
zone "hoge.co.jp"  IN {
        type master;
        file "zone/hoge.co.jp.zone";
};

# chown root:named /etc/named/record.conf
# ls -l /etc/named/record.conf
``````````````````````````````````````

4. ゾーンファイル作成
``````````````````````````````````````
# mkdir -p /var/named/zone
# vi /var/named/zone/hoge.co.jp.zone
-----------以下を追記-----------
$TTL 1D
@               IN SOA  ns.hoge.co.jp. root.hoge.co.jp. (
                                        0       ; serial
                                        1D      ; refresh
                                        1H      ; retry
                                        1W      ; expire
                                        3H )    ; minimum
                IN NS   ns.hoge.co.jp.
@               IN A    14.18.9.11
ns              IN A    172.28.10.13(dnsサーバIP)

# chown -R root:named /var/named/zone
``````````````````````````````````````

5. 構文チェック
``````````````````````````````````````
# named-checkconf /etc/named.conf
→エラーが出ない事
# named-checkzone hoge.co.jp /var/named/zone/hoge.co.jp.zone
→OKが表示される事
``````````````````````````````````````

6. ファイアウォール許可設定
``````````````````````````````````````
# firewall-cmd --add-service=dns --zone=public --permanent
# firewall-cmd --reload
# firewall-cmd --list-all
``````````````````````````````````````

7. resolv.conf修正
※他サーバのresolv.confも修正する
`````````````````````````````````````
# nmcli c m インターフェース名 ipv4.dns dnsサーバIP
`````````````````````````````````````

8. named-chroot起動
`````````````````````````````````````
# systemctl start named-chroot
# systemctl status named-chroot
# systemctl enable named-chroot
`````````````````````````````````````

