■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること
・同期対象として、db作成手順もとに、primary,secondary両方にmysqlを入れておくこと

■ 作業手順

1. host名変更
```````````````````````````````
// drbd(primary,secondary)
$ hostnamectl set-hostname ホスト名
$ hostname
```````````````````````````````

2. drbdインストール
```````````````````````````````
$ su -
# dnf install -y drbd 
```````````````````````````````


[root@spcartdb0101a ~]# cat /etc/drbd.conf
resource r0 {
  protocol B;
  device     /dev/drbd0;
  disk       /dev/sda6;
  meta-disk  /dev/sda5[0];
  syncer {
    rate 128M;
  }

  on spcartdb0101a {
    address    192.168.140.131:7801;
  }
  on spcartdb0101b {
    address    192.168.140.132:7801;
  }

  handlers {
    outdate-peer "/usr/lib64/heartbeat/drbd-peer-outdater -t 5";
  }
  disk {
    fencing resource-only;
  }
}