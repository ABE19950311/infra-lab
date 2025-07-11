■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること
・ansible未対応

■ 作業手順

0. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

1. httpd,nagiosインストール
`````````````````````````````````
# dnf install -y httpd nagios nagios-plugins nagios-plugins-nrpe
# systemctl start httpd
# systemctl start nagios
# systemctl enable httpd
# systemctl enable nagios
# systemctl status httpd
# systemctl status nagios
`````````````````````````````````

2. basic認証初期設定
`````````````````````````````````
# htpasswd -c /etc/nagios/passwd nagiosadmin
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

# systemctl restart nagios
`````````````````````````````````