VM以降等でnic名及びIPアドレスを維持するために設定

//MACアドレスは必ず小文字で表記で書く事
# vi /etc/udev/rules.d/70-persistent-net.rules
SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="<MACアドレス>", NAME="<nic名>"
# udevadm control --reload-rules

