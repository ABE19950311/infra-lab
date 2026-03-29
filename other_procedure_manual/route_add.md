### rtx4[12] coltルータへのルート追加手順書

#### ■ 背景

六本木オフィスからAWS本番環境の監視webコンソールにアクセス可能にするため、 rtx4[12] にAWS本番環境へのルート追加を行う。
方針の変更によりAWS本番環境へのルートが変更になるため、既存のAWS本番環境へのルート(10.21.0.0/16)を削除した後に追加する。

#### ■ 作業対象ホスト

1. rtx41 (10.20.77.71)
2. rtx42 (10.20.77.72)

#### ■ 作業影響

特になし

#### ■ 監視手順

1. https://shnag.estore.co.jp/nagios/ にログインする
2. 下記で検索する
```
*rtx*
```
3. すべての監視対象サービスの Status が OK であることを確認する

#### ■ 作業手順

1. shcc2 経由で rtx4[12] に接続し、 管理者権限に昇格する。

rtx41
```
// local
ssh p-abe@10.200.130.110

// p-abe@shcc2
ssh estore@10.20.77.71

// estore@rtx41
administrator
```

rtx42
```
// local
ssh p-abe@10.200.130.110

// p-abe@shcc2
ssh estore@10.20.77.72

// estore@rtx42
administrator
```

2. 既存のAWS本番環境へのルート(10.21.0.0/16)を削除

```
// root@rtx4[12]
show ip route
show config | grep 'ip route'

no ip route 10.21.0.0/16 gateway 10.20.1.3
save

show ip route
show config | grep 'ip route'
```

3. ルートを設定

```
// root@rtx4[12]
show ip route
show config | grep 'ip route'

ip route 10.21.0.0/16 gateway 10.20.130.15
save

show ip route
show config | grep 'ip route'
```

4. 接続を終了

```
// 管理者ユーザから退出
quit

// ssh接続終了
quit
```

#### ■ 切り戻し手順

1. shcc2 経由で rtx4[12] に接続し、 root に昇格する。

rtx41
```
// local
ssh p-abe@10.200.130.110

// p-abe@shcc2
ssh estore@10.20.77.71

// estore@rtx41
administrator
```

rtx42
```
// local
ssh p-abe@10.200.130.110

// p-abe@shcc2
ssh estore@10.20.77.72

// estore@rtx42
administrator
```

2. ルートを削除

```
// root@rtx4[12]
show ip route
show config | grep 'ip route'

no ip route 10.21.0.0/16 gateway 10.20.130.15
save

show ip route
show config | grep 'ip route'
```

3. 接続を終了

```
// 管理者ユーザから退出
quit

// ssh接続終了
quit
```




--------linux---------------
### cdnlog02 ルート追加作業

---

#### ■ 背景
DX 切り替え作業に伴い、 cdnlog02 に AWS 環境向けのルートを追加する。

#### ■ 作業対象ホスト
1. cdnlog02


#### ■ 作業影響
特になし


#### ■監視手順
本作業実施中は後述の手順で vSphere から下記観点で対象ホストのCPU、メモリ、ディスク、ネットワークのリソース使用状況を確認する。
- 各リソースの使用状況がアラート閾値以下で安定しているか
- アラート定義がない場合は直近1か月の値の範囲を逸脱していないか

アラートの閾値近くを推移している場合は、作業実施可否の確認および、アラートが発報される可能性の周知を運用部に行う。

以下の手順に従い、vSphereのリソースグラフ、アラームを確認する。
異常を確認した場合の対応は、切り戻し手順に従うこと。

1. https://shvcenter65.adi.estore.co.jp/ にログインする
2. 対象ホストを検索する
3. タブメニューから 監視 > パフォーマンス > 概要、　パフォーマンス > 詳細 と進み、各リソースグラフを確認する。
4. タブメニューから 監視 > 問題とアラーム > トリガー済みアラーム と進み、アラームが発生していないことを確認する。


#### ■ 作業手順

1. shcc2 経由で 作業対象ホスト にrootで接続する。
```
// local
$ ssh [user]@10.200.130.110

// shcc2
$ ssh root@nfs-cdnlog02
```
2. 現在のネットワーク設定を確認する。
```
// cdnlog02 (root)
# ip a
# ip r

// network-scripts route の設定ファイルのバックアップを取る。
# ls -l /etc/sysconfig/network-scripts/route*
# cp -p /etc/sysconfig/network-scripts/route-ens224 /root/route-ens224_$(date +%Y%m%d).bak
# ls -l /root/route-ens224_$(date +%Y%m%d).bak
```
3. ルーティングテーブルに対してルートを追加する。
```
# ip route add 10.201.0.0/16 via 10.200.130.15 dev ens224
# ip r
```
4. network-scripts route の設定ファイルにルート情報を追記する。
```
# cat /etc/sysconfig/network-scripts/route-ens224
# nmcli c m ens224 +ipv4.routes "10.201.0.0/16 10.200.130.15"
# cat /etc/sysconfig/network-scripts/route-ens224
```

#### ■ 切り戻し手順
ルート追加作業後、既存の通信経路に異常が生じた場合は、下記手順に従い切り戻し作業を実施すること。

1. shcc2 経由で 作業対象ホスト にrootで接続する。
```
// local
$ ssh [user]@10.200.130.110

// shcc2
$ ssh root@nfs-cdnlog02
```
2. ルーティングテーブルに追加したルートを削除する。
```
// cdnlog02 (root)
# ip r
# ip route delete 10.201.0.0/16 via 10.200.130.15 dev ens224
# ip r
```
3. network-scripts route の設定ファイルをバックアップから切り戻す。
```
# cp -p /root/route-ens224_$(date +%Y%m%d).bak /etc/sysconfig/network-scripts/route-ens224
# cat /etc/sysconfig/network-scripts/route-ens224
# rm /root/route-ens224_$(date +%Y%m%d).bak
```

#### ■ルート変更後疎通確認手順

ルート追加作業とDX切り替え完了後に、下記手順を実施する。

1. shcc2 経由で 作業対象ホスト にrootで接続する。
```
// local
$ ssh [user]@10.200.130.110

// shcc2
$ ssh root@nfs-cdnlog02
```
2. AWS本番環境に対して疎通確認する。
```
// cdnlog02 (root)
# ping -c 8 -W 1 10.201.7.110
```
3. バックアップファイルを削除する。
```
# rm /root/route-ens224_$(date +%Y%m%d).bak
```