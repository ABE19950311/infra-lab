 障害対応の基本原則：「外から内へ」「広から狭へ」 で切り分ける。
---
  ## Step 1. 疎通確認 ─ サーバに到達できるか

  # 対象サーバのIP・ドメイン確認 (調査対象を明確にしてから始める)

  # 死活確認
  $ ping -c 4 <対象IP>

  # SSH接続確認
  $ ssh user@<対象IP>

  # ポート疎通確認 (SSH接続できない場合に使用)
  $ nc -zv <対象IP> <port>

  # DNS名前解決確認
  $ dig <hostname>
  $ nslookup <hostname>

  # ルーティング確認
  $ traceroute <対象IP>

  判断と異常時の対処:
  ・ping NG / ssh NG
    → NW断 or サーバダウン
    → ハイパーバイザコンソールから操作不能の場合
　　　 ハイパーバイザまたは物理マシンから再起動をかける
  ・ping OK / ssh OK
    → サーバ到達・ログイン可能
    → 次STEPでサービス状態確認を行う
  ・ping OK / ssh NG / nc OK
    → FW閉塞 or sshd停止
    → ハイパーバイザコンソールからfirewall・sshdの起動確認
    → ss -nltpでlisten確認
    → 解消しない場合は再起動をかける
  ・ping OK / ssh NG / nc NG
    → サービス停止 or FW閉塞
    → ハイパーバイザコンソールからfirewall-cmd --list-all または iptables -L -n でFW確認
    → ss -nltpでlisten確認
    → FWに問題なければ次STEPでサービス状態確認を行う
  ・port OK / 応答異常
    → アプリ障害
    → 次STEPでサービス状態確認を行う


---
Step 1. サービス状態確認 ─ プロセスは生きているか
// 対象サービスの状態
  $ systemctl status <service>
// # 異常終了しているサービスがないか
  $ systemctl --failed
// プロセス存在確認
  ps aux | grep <service>

  Step 2. ログ確認 ─ 何が起きたか
  # サービスのログ (直近50行)
  $ journalctl -xe -u <service> -n 50
  # 障害発生時刻前後を絞り込む
  $ journalctl -u <service> --since "2026-05-24 10:00" --until "2026-05-24 10:30"
  # カーネル・システムログ
  $ journalctl -k --since "1 hour ago"
  # /var/log配下
  $ tail -f /var/log/messages

  ---
  Step 3. リソース確認 ─ リソース枯渇していないか

  # CPU・ロードアベレージ・メモリ
  $ top -bn1 | head -20
  $ vmstat 1 5
  # メモリ詳細
  $ free -h

  # ディスク使用量 (フルはサービス停止の直接原因になる)
  $ df -h
  $ df -PhT
  $ du -sh /var/log/* | sort -hr | head -n 15

  # ディスクI/O
  $ iostat -xz 1 5
  ---
  Step 4. ネットワーク状態確認 ─ 接続は正常か

  # ポートのリッスン状態
  $ ss -nltp
  # 接続数・状態の集計
  $ ss -s

  # ファイアウォール確認
  $ firewall-cmd --list-all
  $ iptables -L -n -v
  ---
  Step 5. システム基盤確認 ─ 見落としがちな要因

  # 時刻同期 (ずれはログ解析・証明書・レプリケーションに影響)
  $ timedatectl status
  $ chronyc tracking

  # ファイルディスクリプタ上限
  $ ulimit -n
  $ ls /proc/<pid>/fd | wc -l
  # OOM Killerの痕跡
  $ journalctl -k | grep -i "oom\|killed process"

  # ディスクエラーの痕跡
  journalctl -k | grep -i "error\|fail\|i/o error"

  ---             
  まとめ：確認の流れ                                                                                   
                  
  Step 0: 疎通確認       → 到達できるか
    ↓                                                                                                  
  Step 1: サービス状態   → プロセスは生きているか
    ↓                                                                                                  
  Step 2: ログ確認       → 何が起きたか・いつからか
    ↓                                                                                                  
  Step 3: リソース確認   → 枯渇していないか
    ↓                                                                                                  
  Step 4: NW状態確認     → 接続・FWは正常か
    ↓                                                                                                  
  Step 5: 基盤確認       → 時刻・fd・OOM等の見落とし
                                                                                                       
  Step 0〜2 で大半の障害は原因が絞れます。3以降は並行して確認することも多いです。             