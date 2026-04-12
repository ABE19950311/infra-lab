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
# nmcli c m profile名 ipv4.gateway gatewayIP
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

---

## ■イーサネット作業手順(nmcliなし)

### 1. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
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

# ifup interface
`````````````````````````````````````

## ■wifi作業手順(nmcliなし)

### 1. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
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

# ifup interface
`````````````````````````````````````

