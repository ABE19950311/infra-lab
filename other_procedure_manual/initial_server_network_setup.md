## ■ イーサネット作業手順(nmcli)

### 1. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

### 2. network,NetworkManager,インターフェース起動確認
`````````````````````````````````````
# systemctl status network
# systemctl status NetworkManager
# nmcli c show
→NAME(profile名)とDEVICE名が一致してない場合は合わせておく
# nmcli con mod "今のprofile名" connection.id "変更先profile名"
# nmcli device status
→disconnectedになっている場合は以下を実施
# nmcli c up profile名
# ip a
`````````````````````````````````````

### 3. インターフェース各設定
`````````````````````````````````````
// IP固定
# nmcli c m profile名 ipv4.addresses 固定IP/CIDR
// デフォゲ設定
# nmcli c m profile名 ipv4.gateway gatewayIP (route metric)
// dnsサーバ、ベース名設定
# nmcli c m profile名 ipv4.dns dnsサーバIP
# nmcli c m profile名 ipv4.dns-search サーチベース名
// ipv4割り当てを手動にする
# nmcli c m profile名 ipv4.method manual

# nmcli c up profile名
# nmcli c show profile名
`````````````````````````````````````

## ■ wifi作業手順(nmcli)

### 1. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

### 2. network,NetworkManager,NetworkManager-wifi,インターフェース起動確認
`````````````````````````````````````
# systemctl status network
# systemctl status NetworkManager
# systemctl status NetworkManager-wait-online
→ない場合は以下実施
# dnf install -y NetworkManager-wifi wpa_supplicant

// wifiに接続
# nmcli device wifi connect "ssid" password "password" name インターフェース名
// インターフェース名とprofle名一致確認
# nmcli c show
// インターフェース起動確認
# nmcli device status
→Error: No Wi-Fi device found.となる場合は以下を実施

# nmcli con add type wifi ifname インターフェース名 con-name "profile名" ssid "ssid"
# nmcli con mod "profile名" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "パスワード"
# nmcli con up "profile名"
# nmcli c show
# nmcli device status
# ip a

// 使わないwifiプロファイルは削除するか割り当てを無効化しておく
# nmcli ...
`````````````````````````````````````

### 3. インターフェース各設定
`````````````````````````````````````
// IP固定
# nmcli c m profile名 ipv4.addresses 固定IP/CIDR
// デフォゲ設定
# nmcli c m profile名 ipv4.gateway gatewayIP
// dnsサーバ、ベース名設定
# nmcli c m profile名 ipv4.dns dnsサーバIP
# nmcli c m profile名 ipv4.dns-search サーチベース名
// ipv4割り当てを手動にする
# nmcli c m profile名 ipv4.method manual

# nmcli c up profile名
# nmcli c show profile名
`````````````````````````````````````

---------------------------------------------------------

## ■イーサネット作業手順(nmcliなし)

### 1. host名変更
```````````````````````````````
# vi /etc/sysconfig/network
--------以下を変更・追記---------------
HOSTNAME=ホスト名
-------------------------------------
// カーネルへ即時反映（再起動せずに反映させる場合）
# hostname ホスト名

// 確認
# hostname
```````````````````````````````

2. network,NetworkManager,インターフェース起動確認
``````````````````````````````````````
# service network status
# ip a
→インターフェースdownしている場合は以下を実施
# ifup target_interface
# ip a
# ifconfig -a
`````````````````````````````````````

3. IP固定
`````````````````````````````````````
# vi /etc/sysconfig/network-scripts/ifcfg-target_interface
-------------以下の様に修正---------
DEVICE=eth0
HWADDR=00:0C:29:EC:79:93
TYPE=Ethernet
UUID=1a72fc87-8f6f-44b7-8732-5e9dc5f9842c
//起動時有効になるように
ONBOOT=yes
NM_CONTROLLED=yes
#BOOTPROTO=dhcp
BOOTPROTO=static
//以下IP設定
IPADDR=固定したいIP
NETMASK=
GATEWAY=
DNS1=

# ifdown interface
# ifup interface
`````````````````````````````````````

## ■wifi作業手順(nmcliなし)

### 1. host名変更
```````````````````````````````
# vi /etc/sysconfig/network
--------以下を変更・追記---------------
HOSTNAME=ホスト名
-------------------------------------
// カーネルへ即時反映（再起動せずに反映させる場合）
# hostname ホスト名

// 確認
# hostname
```````````````````````````````

2. wpa_supplicantの設定とWi-Fi接続
``````````````````````````````````````
// wpa_supplicantがインストールされているか確認
# rpm -qa | grep wpa_supplicant
（※無い場合は yum install wpa_supplicant でインストール）

// インターフェース名の確認（wlan0 など）
# ifconfig -a

// SSIDとパスワードから設定ファイルを生成
# wpa_passphrase "ssid" "パスワード" >> /etc/wpa_supplicant/wpa_supplicant.conf

// 設定ファイルの調整（平文パスワードの削除など）
# vi /etc/wpa_supplicant/wpa_supplicant.conf

// wpa_supplicant の起動設定（使用するインターフェースを指定）
# vi /etc/sysconfig/wpa_supplicant
--------以下内容で編集---------------
INTERFACES="-iwlan0"
DRIVERS="-Dwext"  # ドライバは環境により -Dnl80211 の場合もあります
-------------------------------------
`````````````````````````````````````

3. IP固定
`````````````````````````````````````
// Wi-Fi用インターフェースの設定ファイルを編集
# vi /etc/sysconfig/network-scripts/ifcfg-wlan0
--------以下内容で編集---------------
DEVICE=wlan0
TYPE=Wireless
ONBOOT=yes
BOOTPROTO=none
IPADDR=固定IP
NETMASK=サブネットマスク
GATEWAY=gatewayIP
-------------------------------------

// DNSサーバの設定
# vi /etc/resolv.conf
--------以下内容で編集---------------
search サーチベース名
nameserver dnsサーバIP
-------------------------------------

// wpa_supplicantサービスの起動と自動起動設定
# chkconfig wpa_supplicant on
# service wpa_supplicant start

// ネットワークサービスの再起動
# service network restart

// 接続確認
# iwconfig wlan0   # SSIDに正しく関連付け(Associated)されているか確認
# ifconfig wlan0
# ping -c 3 gatewayIP
`````````````````````````````````````

