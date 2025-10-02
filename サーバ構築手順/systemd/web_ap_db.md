■ 前提条件
・OS
[root@c22383d8a0fb /]# cat /etc/redhat-release
AlmaLinux release 8.10 (Cerulean Leopard)
・epel-releaseインストール済み
・ミドルウェアインストール時にインターネットへの経路が存在していること
・ansible未対応
・SSLはオレオレ証明書で対応

■ web(httpd)

0. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

1. apache、mod_ssl,opensslインストール
```````````````````````````````
# dnf install -y httpd mod_ssl openssl
# systemctl start httpd
# systemctl enable httpd
# systemctl status httpd
```````````````````````````````

2. apサーバへのプロキシ設定追加
```````````````````````````````
# vi /etc/httpd/conf/httpd.conf
---------以下を追加する---------
# HTTP: リダイレクトのみ
<VirtualHost *:80>
    ServerName localhost
    Redirect permanent / https://localhost/
</VirtualHost>

# HTTPS: 実際の処理はこちら
<VirtualHost *:443>
    ServerName localhost
    DocumentRoot /var/www/html

    SSLEngine on
    SSLCertificateFile /etc/httpd/conf.d/certs/server.crt
    SSLCertificateKeyFile /etc/httpd/conf.d/certs/server.key
    # 必要に応じて中間証明書も指定
    # SSLCertificateChainFile /etc/pki/tls/certs/chain.crt

    <FilesMatch \.php$>
        SetHandler "proxy:fcgi://apサーバのIP:9000"
    </FilesMatch>

    DirectoryIndex index.php
    <Directory "/var/www/html">
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```````````````````````````````

3. オレオレ証明書作成
※参照
https://qiita.com/taitai22_1/items/019845da881733d522c2
https://tex2e.github.io/blog/protocol/certificate-with-ip-addr
```````````````````````````````
# openssl genrsa -out server.key 2048
# openssl req -out server.csr -key server.key -new
# vi san.txt
----------以下内容を追記---------
// IP,ドメインで内容は適宜変更する
subjectAltName = IP:webサーバのIP
            or
subjectAltName=DNS:localhost,IP:127.0.0.1

# openssl x509 -req -days 3650 -signkey server.key -in server.csr -out server.crt -extfile san.txt
// 確認
# openssl x509 -text < server.crt

// pem
# cat server.crt server.key > server.pem
```````````````````````````````

4. オレオレ証明書適用
```````````````````````````````
# mkdir -p /etc/httpd/conf.d/certs
# mv server.crt server.key /etc/httpd/conf.d/certs/
# chown -R root:root /etc/httpd/conf.d/certs
# chmod -R 644 /etc/httpd/conf.d/certs
# systemctl restart httpd
実施後、ブラウザ側でオレオレ証明書のインポートとブラウザ再起動をする
参照chrome
※証明書は、「信頼されたルート証明機関」配下にインポートする
https://kekaku.addisteria.com/wp/20190327053337#toc7
```````````````````````````````

5. firewall,selinuxが無効になっている事を確認
```````````````````````````````
# systemctl status firewalld
⇒起動してたら、stopとdisable
# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
```````````````````````````````

■ ap(php,php-fpm)

0. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

1. php,php-fpmインストール
```````````````````````````````
# dnf install -y php php-cli php-fpm
# systemctl start php-fpm
# systemctl enable php-fpm
# systemctl status php-fpm
```````````````````````````````

2. php-fpm listen設定
```````````````````````````````
# vi /etc/php-fpm.d/www.conf
---------以下内容で修正---------
// 9000portでlistenするようにする
listen = apサーバのIP:9000
// デフォルトはlocalhostのみ許可してないため、webサーバのIPを許可する
listen.allowed_clients = webサーバのIP

# systemctl restart php-fpm
```````````````````````````````

3. 疎通確認用テストファイル作成
```````````````````````````````
# echo "<?php phpinfo(); ?>" > /var/www/html/index.php
```````````````````````````````

4. 簡単なtodoアプリ作成
```````````````````````````````
// PDO使用用
# dnf install -y php-pdo php-mysqlnd
# vi /var/www/html/todo.php
----------以下を追記-----------
<?php
// ===== DB接続 =====
$host = 'dbサーバのIP';
$db   = 'todoapp';
$user = 'your_user';      // ← あなたのDBユーザー名
$pass = 'your_pass';      // ← あなたのDBパスワード
$charset = 'utf8mb4';

$dsn = "mysql:host=$host;dbname=$db;charset=$charset";
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
];

try {
    $pdo = new PDO($dsn, $user, $pass, $options);
} catch (PDOException $e) {
    exit('DB接続エラー: ' . $e->getMessage());
}

// ===== 新規追加処理 =====
if ($_SERVER['REQUEST_METHOD'] === 'POST' && !empty($_POST['title'])) {
    $stmt = $pdo->prepare("INSERT INTO todos (title) VALUES (?)");
    $stmt->execute([$_POST['title']]);
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// ===== 削除処理 =====
if (isset($_GET['delete'])) {
    $stmt = $pdo->prepare("DELETE FROM todos WHERE id = ?");
    $stmt->execute([$_GET['delete']]);
    header("Location: " . strtok($_SERVER["REQUEST_URI"], '?'));
    exit;
}

// ===== 一覧取得 =====
$stmt = $pdo->query("SELECT * FROM todos ORDER BY created_at DESC");
$todos = $stmt->fetchAll();
?>

<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <title>ToDoリスト</title>
</head>
<body>
    <h1>ToDoリスト</h1>

    <form method="POST">
        <input type="text" name="title" placeholder="やることを入力" required>
        <button type="submit">追加</button>
    </form>

    <ul>
        <?php foreach ($todos as $todo): ?>
            <li>
                <?= htmlspecialchars($todo['title']) ?>
                <a href="?delete=<?= $todo['id'] ?>" onclick="return confirm('削除しますか？');">[削除]</a>
            </li>
        <?php endforeach; ?>
    </ul>
</body>
</html>
```````````````````````````````

5. firewall,selinuxが無効になっている事を確認
```````````````````````````````
# systemctl status firewalld
⇒起動してたら、stopとdisable
# getenforce
⇒disableでなければ、以下無効設定をして再起動
# vi /etc/selinux/config
----------以下を設定------------
SELINUX=disabled

# reboot
```````````````````````````````

■ db(mysql)

0. host名変更
```````````````````````````````
# hostnamectl set-hostname ホスト名
# hostname
```````````````````````````````

1. mysqlインストール
```````````````````````````````
# dnf install -y mysql-server
# systemctl start mysqld
# systemctl enable mysqld
# systemctl status mysqld
```````````````````````````````

2. 外部接続許可用ユーザ作成
```````````````````````````````
# mysql -u root
mysql> CREATE USER 'sample_user' IDENTIFIED BY 'hoge';
mysql> GRANT ALL PRIVILEGES ON *.* TO 'sample_user'@'%' WITH GRANT OPTION;
```````````````````````````````

3. テスト用データベース、テーブル作成
```````````````````````````````
mysql> CREATE DATABASE todoapp CHARACTER SET utf8mb4;
mysql> USE todoapp;
mysql> CREATE TABLE todos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
mysql> exit;
```````````````````````````````