■ vmware workstation pro
・almalinux8


・centos6
```````````````````````````````
1. ホーム -> 新規仮想マシンの作成 を押下する
2. 標準を選択し次へ -> osタイプがminimalの場合は 後でOSをインストール を選択して次へ
3. ゲストOS Linux および バージョン CentOS 6 64ビット を選択し次へ
4. 任意の仮想マシン名を入力し次へ -> 仮想ディスクを複数のファイルに分割 を選択して完了
5. 仮想マシンの設定を編集する -> CD/DVD(IDE)から以下内容に修正する
デバイスのステータス -> 起動時に接続をチェック
接続 -> ISOイメージファイル使用する を選択しisoを指定する
6. この仮想マシンをパワーオンする を押下
7. Install or upgrade an existing system を選択
8. To begin testing the media -> Skip
9. 基本ストレージデバイス を選択
10. 構いません、どのようなデータであっても破棄してください を選択
11. 既存のLinuxシステムを入れ替える を選択
12. 変更をディスクに書き込む を選択
```````````````````````````````


・windowsServer2022
https://zenn.dev/aws_gissan/articles/59f276c565fc45
https://www.ubackup.com/jp/articles/install-windows-sever-2022-0400-tc.html