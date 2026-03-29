   
■ 作業手順(nmcli)

1. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

2. network,NetworkManager,インターフェース起動確認
``````````````````````````````````````
# systemctl status network
# systemctl status NetworkManager
# nmcli device status
→disconnectedになっている場合は以下を実施
# nmcli c up "インターフェース名"
# ip a
`````````````````````````````````````

3. インターフェース各設定
`````````````````````````````````````
// IP固定
# nmcli c m "インターフェース名" ipv4.addresses "固定IP/CIDR"
// デフォゲ設定
# nmcli c m "インターフェース名" ipv4.gateway "gatewayIP"
// dnsサーバ、ベース名設定
# nmcli c m "インターフェース名" ipv4.dns "dnsサーバIP"
# nmcli c m "インターフェース名" ipv4.dns-search "サーチベース名"
// ipv4割り当てを手動にする
# nmcli c m "インターフェース名" ipv4.method manual

# nmcli c down "インターフェース名"
# nmcli c up "インターフェース名"
# nmcli device show "インターフェース名"
`````````````````````````````````````

---

■作業手順(nmcliなし)

1. host名変更
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

# ifdown interface
# ifup interface
`````````````````````````````````````

