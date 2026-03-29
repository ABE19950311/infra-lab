### spbcgi0904_spgcgi0904_lb追加手順書


■ 背景
追加したset9cgiサーバをロードバランサーに追加する。


■ 作業対象ホスト

shcc2
shlb200


■ 作業手順

1. shlb200 に接続する
``````````````````````````````````
// shcc2
$ ssh nsroot@int-shlb200
``````````````````````````````````

2. IPアドレスベースのサーバーを作成する
``````````````````````````````````
// shlb200
nsroot@SHLB201> add server rip-spbcgi0904 10.60.142.72
nsroot@SHLB201> add server rip-spgcgi0904 10.60.142.132
``````````````````````````````````

3. サービスグループにbindする
``````````````````````````````````
// shlb200
nsroot@SHLB201> bind serviceGroup grp-spbcgi09-http rip-spbcgi0904 80
nsroot@SHLB201> bind serviceGroup grp-spgcgi09-http rip-spgcgi0904 80
``````````````````````````````````


■ 事後確認

1. 追加した設定とStateに問題がない事を確認する
``````````````````````````````````
// shlb200
nsroot@SHLB201> sh ns run | grep spbcgi090
⇒以下の設定が存在することを確認
add server rip-spbcgi0904 10.60.142.72
bind serviceGroup grp-spbcgi09-http rip-spbcgi0904 80

nsroot@SHLB201> sh ns run | grep spgcgi090
⇒以下の設定が存在することを確認
add server rip-spgcgi0904 10.60.142.132
bind serviceGroup grp-spgcgi09-http rip-spgcgi0904 80

nsroot@SHLB201> sh serviceGroup grp-spbcgi09-http
⇒以下の設定が存在することを確認
10.60.142.72:80   State: UP       Server Name: rip-spbcgi0904

nsroot@SHLB201> sh serviceGroup grp-spgcgi09-http
⇒以下の設定が存在することを確認
10.60.142.132:80   State: UP       Server Name: rip-spgcgi0904
``````````````````````````````````

2. アクセスログにステータスコード200のアクセスが来ている事を確認する
``````````````````````````````````
// spbcgi0904、spgcgi0904
$ sudo -i
# tail -f /var/log/httpd/access_log.YYYYMMDDHH
``````````````````````````````````


■ 切り戻し手順

1. shlb200 に接続する。
``````````````````````````````````
// shcc2
$ ssh nsroot@int-shlb200
``````````````````````````````````

2. サービスグループからunbindする
``````````````````````````````````
nsroot@SHLB201> unbind serviceGroup grp-spbcgi09-http rip-spbcgi0904 80
nsroot@SHLB201> uubind serviceGroup grp-spgcgi09-http rip-spgcgi0904 80
``````````````````````````````````


■作業影響・周知
・slackから部内へ作業周知
・作業影響なし




