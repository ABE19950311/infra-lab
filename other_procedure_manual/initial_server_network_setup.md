   
■ 作業手順(nmcli)

1. network,NetworkManager,インターフェース起動確認
``````````````````````````````````````
# systemctl status network
# systemctl status NetworkManager
# nmcli device status
→disconnectedになっている場合は以下を実施
# nmcli c up target_interface
# ip a
`````````````````````````````````````

2. IP固定
`````````````````````````````````````
# vi /etc/sysconfig/network-scripts/ifcfg-target_interface
-------------以下の様に修正---------
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
#BOOTPROTO=dhcp
BOOTPROTO=static
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
NAME=ens160
UUID=d55bbac4-898f-4773-99d3-b91777c13588
DEVICE=ens160
//起動時有効になるように
ONBOOT=yes
//以下IP設定
IPADDR=固定したいIP
NETMASK=
GATEWAY=
DNS1=

# nmcli c reload
# nmcli c down target_interface
# nmcli c up target_interface
`````````````````````````````````````

---

■作業手順(nmcliなし)

1. network,NetworkManager,インターフェース起動確認
``````````````````````````````````````
# service network status
# ip a
→インターフェースdownしている場合は以下を実施
# ifup target_interface
# ip a
# ifconfig -a
`````````````````````````````````````

2. IP固定
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

