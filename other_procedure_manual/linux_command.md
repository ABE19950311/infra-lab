#### awk
```
// ログから対象行の件数調べる
# cat /var/log/httpdlog | awk '{print $6}' | sort | uniq | sort -nr

// 1時間後のメール送信数を調べる
# cat /var/log/maillog* | grep "status=sent" | awk '{print $1, $2, substr($3,1,2)}' | sort | uniq -c | sort -nr
```

#### tcpdump
```
// interfaceがens160、送信元port80、送信元IPが192.168.211.251 のパケットをキャプチャ
# tcpdump -i ens160 src port 80 and host 192.168.211.251
// 名前解決しない（不要な通信を避けるため）
# tcpdump -n -i ens160 src port 80 and host 192.168.211.251
// 80portへの通信をキャプチャしてファイルに出力
# tcpdump -n -i ens160 dst port 80 -w tcpdump.pcap
```

---

#### netstat,ss
```
// LISTENポート確認
// TCP
# ss -nltp
# netstat -nltp
// UDP
# ss -nlup
# netstat -nlup

// ネットワーク統計情報表示
# netstat -s
# ss -s
// interface毎
# netstat -i
```

---

#### watch
```
// 1秒毎に、interface毎の統計を差分をハイライトして表示する
# watch -d -n 1 netstat -i
// drbdの同期状態を確認する（作業で一時的にdrbdの同期を止めて再同期した後の確認等）
# watch cat /proc/drbd
```

---

#### nc
```
// 一時的にportをLISTENさせる。目的としては、ミドルウェア未導入の状態でサーバ側疎通確認をするとき
# nc -kl 対象port
// バックグラウンド実行
# nc -kl 対象port &
```

---

#### curl

---

#### wget

---

#### dig,nslookup

---

#### ping
```
// 普通に対象IPの疎通確認を5回
# ping -c 対象IP
// DNSチェックと疎通確認を同時に
# ping 対象ドメイン
```

---

#### telnet
```
//単純なTCPportの疎通確認
# telnet 対象サーバ 対象port
```

#### traceroute

---

#### openssl

---

#### ifconfig,ip