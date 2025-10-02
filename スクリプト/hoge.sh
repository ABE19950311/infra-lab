サーバーを運用していると、ログファイルはどんどん溜まっていきます。ディスクを圧迫する前に、古いログを自動で圧縮・削除するスクリプトです。

ユースケース
毎日深夜に実行し、30日以上前の.logファイルを圧縮（gzip）する。

さらに、180日以上前の圧縮済みログファイル (.gz) を削除する。

スクリプト (organize_logs.sh)
Bash

#!/bin/bash

# スクリプト実行中にエラーが発生したら、ただちに終了する
set -e

# 対象のログディレクトリ
LOG_DIR="/var/log/myapp"
# 圧縮対象とする日数 (30日より前)
COMPRESS_DAYS=30
# 削除対象とする日数 (180日より前)
DELETE_DAYS=180

echo "===== Log Organization Start: $(date) ====="

# 1. 古いログファイル(.log)を圧縮する
echo "Compressing files older than ${COMPRESS_DAYS} days..."
find "${LOG_DIR}" -type f -name "*.log" -mtime +"${COMPRESS_DAYS}" -print0 | while IFS= read -r -d $'\0' logfile; do
    echo "  Compressing: ${logfile}"
    gzip "${logfile}"
done

# 2. さらに古い圧縮ファイル(.gz)を削除する
echo "Deleting files older than ${DELETE_DAYS} days..."
find "${LOG_DIR}" -type f -name "*.log.gz" -mtime +"${DELETE_DAYS}" -print0 | while IFS= read -r -d $'\0' archfile; do
    echo "  Deleting: ${archfile}"
    rm "${archfile}"
done

echo "===== Log Organization Finished: $(date) ====="
ポイント解説
set -e: スクリプトの途中でコマンドが失敗した場合（例: rmに失敗）、スクリプト全体を即座に停止させます。意図しない動作を防ぐためのお守りです。

find ... -mtime +N: N日より前に更新されたファイルを検索します。

-print0 | while ... read -r -d $'\0': ファイル名にスペースや特殊文字が含まれていても安全に処理するための定型句です。

使い方
上記コードをorganize_logs.shとして保存します。

LOG_DIRを自分の環境に合わせて書き換えます。

実行権限を付与します: chmod +x organize_logs.sh

crontab -eでcronに登録し、毎日深夜などに自動実行させます。例: 0 2 * * * /path/to/organize_logs.sh

💾 2. 特定ディレクトリのバックアップスクリプト
重要なファイルが格納されたディレクトリを、日付入りのファイル名で圧縮し、バックアップ先に保存します。

ユースケース
Webサイトのコンテンツディレクトリ (/var/www/html) を毎日バックアップする。

バックアップは7世代分だけ残し、それより古いものは自動で削除する。

スクリプト (backup.sh)
Bash

#!/bin/bash
set -e

# --- 設定 ---
# バックアップ対象ディレクトリ
SOURCE_DIR="/var/www/html"
# バックアップファイルの保存先ディレクトリ
DEST_DIR="/var/backups/website"
# バックアップの世代数
RETENTION_DAYS=7
# --- 設定ここまで ---

# 日付フォーマット (例: website-20251001_113000.tar.gz)
TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
FILENAME="$(basename "${SOURCE_DIR}")-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="${DEST_DIR}/${FILENAME}"

# 保存先ディレクトリがなければ作成
mkdir -p "${DEST_DIR}"

echo "Starting backup of ${SOURCE_DIR} to ${ARCHIVE_PATH}..."

# tarコマンドでディレクトリを圧縮
# c: 作成, z: gzip圧縮, f: ファイル名を指定
tar -czf "${ARCHIVE_PATH}" -C "$(dirname "${SOURCE_DIR}")" "$(basename "${SOURCE_DIR}")"

echo "Backup successful."

# 古いバックアップを削除
echo "Cleaning up old backups (older than ${RETENTION_DAYS} days)..."
find "${DEST_DIR}" -type f -name "*.tar.gz" -mtime +"${RETENTION_DAYS}" -delete

echo "Cleanup complete."
ポイント解説
TIMESTAMP=$(date "+..."): dateコマンドで現在の日時を取得し、ファイル名が重複しないようにします。

mkdir -p: 親ディレクトリが存在しない場合でも、まとめてディレクトリを作成してくれる便利なオプションです。

tar -C: tarがアーカイブを作成する前に、指定したディレクトリへ移動します。これにより、アーカイブ内のパスが /var/www/html/... のような絶対パスではなく html/... のような相対パスになり、リストアしやすくなります。

🌐 3. Webサービスの死活監視スクリプト
特定のWebサイトが正常に応答しているか（HTTPステータスコードが200か）を定期的にチェックし、問題があれば通知します。

ユースケース
自社のWebサイトがダウンしていないか、5分おきにチェックする。

もし応答が200番台でない場合、ログにエラーを記録し、メールやSlackなどで通知する。

スクリプト (health_check.sh)
Bash

#!/bin/bash

# 監視対象のURL
TARGET_URL="https://www.example.com"
# ログファイルのパス
LOG_FILE="/var/log/health_check.log"

# curlでHTTPステータスコードを取得
# -s: サイレントモード, -o /dev/null: ボディ出力を捨てる, -w "%{http_code}": ステータスコードだけ出力
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET_URL}")

# 現在の日時
NOW=$(date "+%Y-%m-%d %H:%M:%S")

# HTTPステータスコードが200番台かチェック
if [[ "${HTTP_CODE}" -ge 200 && "${HTTP_CODE}" -lt 300 ]]; then
  # 正常な場合
  echo "[${NOW}] [SUCCESS] Status code is ${HTTP_CODE} for ${TARGET_URL}" >> "${LOG_FILE}"
else
  # 異常な場合
  ERROR_MESSAGE="[${NOW}] [ERROR] Status code is ${HTTP_CODE} for ${TARGET_URL}"
  echo "${ERROR_MESSAGE}" | tee -a "${LOG_FILE}"
  
  # --- 通知処理 (必要に応じてコメントアウトを解除・編集) ---
  # 例: メールで通知
  # echo "${ERROR_MESSAGE}" | mail -s "Health Check Alert!" admin@example.com
  
  # 例: Slackに通知
  # /path/to/slack_notify.sh "${ERROR_MESSAGE}"
fi
ポイント解説
HTTP_CODE=$(curl ...): コマンドの実行結果を変数に格納する、シェルスクリプトの基本テクニックです。

if [[ ... && ... ]]: Bashの高機能な条件式です。ここでは「200以上かつ300未満」という条件を判定しています。

tee -a: 標準出力（画面）とファイルの両方に、同じ内容を追記（append）します。エラー発生時に画面で確認しつつ、ログにも残せるので便利です。

これらのスクリプトをベースに、自分の業務に合わせてカスタマイズすることで、日々の定型作業を大幅に効率化できます。

