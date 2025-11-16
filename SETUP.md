# セットアップ手順書

## 前提条件

### AWS EC2インスタンス要件
- **OS**: Ubuntu 22.04 LTS
- **インスタンスタイプ**: t3.medium以上推奨
  - vCPU: 2コア以上
  - メモリ: 4GB以上
- **ストレージ**: 20GB以上
- **セキュリティグループ**:
  - インバウンド: 8000番ポート（HTTP）
  - インバウンド: 22番ポート（SSH）
  - アウトバウンド: すべて許可

### 必要な情報
- IBM Instana Agent Key
- IBM Instana Endpoint URL
- （オプション）AWS RDSを使用する場合はエンドポイント情報

---

## セットアップ手順

### Step 1: EC2インスタンスへの接続

```bash
# SSH接続
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### Step 2: システムの更新

```bash
# パッケージリストの更新
sudo apt update && sudo apt upgrade -y

# 必要な基本パッケージのインストール
sudo apt install -y git curl wget vim build-essential
```

### Step 3: PostgreSQLのインストール

```bash
# PostgreSQLのインストール
sudo apt install -y postgresql postgresql-contrib

# PostgreSQLの起動と自動起動設定
sudo systemctl start postgresql
sudo systemctl enable postgresql

# PostgreSQLのステータス確認
sudo systemctl status postgresql
```

### Step 4: データベースとユーザーの作成

```bash
# PostgreSQLユーザーに切り替え
sudo -u postgres psql

# 以下をPostgreSQLコンソールで実行
CREATE DATABASE demo_app;
CREATE USER demo_user WITH PASSWORD 'demo_password_123';
ALTER ROLE demo_user SET client_encoding TO 'utf8';
ALTER ROLE demo_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE demo_user SET timezone TO 'Asia/Tokyo';
GRANT ALL PRIVILEGES ON DATABASE demo_app TO demo_user;

# 接続権限の付与（PostgreSQL 15以降の場合）
\c demo_app
GRANT ALL ON SCHEMA public TO demo_user;

# 終了
\q
```

### Step 5: Pythonとvirtualenvのセットアップ

```bash
# Python 3とpipのインストール確認
python3 --version
sudo apt install -y python3-pip python3-venv

# 作業ディレクトリの作成
mkdir -p ~/demo
cd ~/demo
```

### Step 6: デモアプリケーションのセットアップ

```bash
# ZIPファイルの解凍
cd ~
unzip wrong-is-new-down-demo.zip
cd wrong-is-new-down-demo

# ディレクトリ構造:
# /home/ubuntu/wrong-is-new-down-demo/  ← プロジェクトルート
#   ├── demo_app/                      ← Djangoアプリケーション
#   ├── scripts/                       ← 運用スクリプト
#   └── setup_ec2.sh                  ← セットアップスクリプト

# Python仮想環境の作成
python3 -m venv venv

# 仮想環境の有効化
source venv/bin/activate

# 依存パッケージのインストール（後述のrequirements.txtから）
pip install --upgrade pip
pip install -r requirements.txt
```

### Step 7: IBM Instana Agentのインストール

```bash
# 環境変数の設定
export INSTANA_AGENT_KEY="your-agent-key-here"
export INSTANA_AGENT_ENDPOINT="your-endpoint-url"

# Agentインストールスクリプトのダウンロードと実行
curl -o setup_agent.sh https://setup.instana.io/agent
chmod 700 ./setup_agent.sh
sudo ./setup_agent.sh -a $INSTANA_AGENT_KEY -t dynamic -e $INSTANA_AGENT_ENDPOINT

# Agentのステータス確認
sudo systemctl status instana-agent

# ログ確認
sudo journalctl -u instana-agent -f
```

### Step 8: Djangoアプリケーションのセットアップ

```bash
# demo_appディレクトリに移動
cd ~/wrong-is-new-down-demo/demo_app

# 環境変数の設定（.envファイルを作成）
cat > .env << EOF
DEBUG=True
SECRET_KEY=your-secret-key-here-change-in-production
DATABASE_NAME=demo_app
DATABASE_USER=demo_user
DATABASE_PASSWORD=demo_password_123
DATABASE_HOST=localhost
DATABASE_PORT=5432
ALLOWED_HOSTS=*
EOF

# データベースマイグレーション
python manage.py migrate

# スーパーユーザーの作成（オプション）
python manage.py createsuperuser

# 静的ファイルの収集
python manage.py collectstatic --noinput
```

### Step 9: アプリケーションの起動

```bash
# 開発サーバーの起動
python manage.py runserver 0.0.0.0:8000

# または、本番環境ではGunicornを使用
# pip install gunicorn
# gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 3
```

### Step 10: 動作確認

```bash
# 別のターミナルで接続テスト
curl http://localhost:8000/login/

# ブラウザでアクセス
# http://<EC2-PUBLIC-IP>:8000/login/
```

---

## 本番環境向けの追加設定

### systemdサービスの作成（自動起動設定）

```bash
# サービスファイルの作成
sudo vim /etc/systemd/system/demo-app.service
```

```ini
[Unit]
Description=Wrong is the new Down Demo Application
After=network.target postgresql.service

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/demo/wrong-is-new-down-demo/demo_app
Environment="PATH=/home/ubuntu/demo/wrong-is-new-down-demo/venv/bin"
ExecStart=/home/ubuntu/demo/wrong-is-new-down-demo/venv/bin/gunicorn \
    --workers 3 \
    --bind 0.0.0.0:8000 \
    config.wsgi:application

[Install]
WantedBy=multi-user.target
```

```bash
# サービスの有効化と起動
sudo systemctl daemon-reload
sudo systemctl start demo-app
sudo systemctl enable demo-app

# ステータス確認
sudo systemctl status demo-app
```

### Nginxのセットアップ（リバースプロキシ）

```bash
# Nginxのインストール
sudo apt install -y nginx

# 設定ファイルの作成
sudo vim /etc/nginx/sites-available/demo-app
```

```nginx
server {
    listen 80;
    server_name <EC2-PUBLIC-IP>;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /static/ {
        alias /home/ubuntu/demo/wrong-is-new-down-demo/demo_app/staticfiles/;
    }
}
```

```bash
# 設定の有効化
sudo ln -s /etc/nginx/sites-available/demo-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

---

## トラブルシューティング

### PostgreSQL接続エラー

```bash
# PostgreSQLの接続設定を確認
sudo vim /etc/postgresql/14/main/pg_hba.conf

# 以下の行があることを確認
# local   all             all                                     peer
# host    all             all             127.0.0.1/32            md5

# PostgreSQL再起動
sudo systemctl restart postgresql
```

### ポート8000が使用できない

```bash
# ポートの使用状況確認
sudo lsof -i :8000

# プロセスの終了
kill -9 <PID>
```

### Instana Agentが起動しない

```bash
# ログの詳細確認
sudo journalctl -u instana-agent -n 100 --no-pager

# 設定ファイルの確認
sudo vim /opt/instana/agent/etc/instana/configuration.yaml

# Agent再起動
sudo systemctl restart instana-agent
```

### Djangoのマイグレーションエラー

```bash
# データベース接続テスト
python manage.py dbshell

# マイグレーションの初期化
python manage.py migrate --run-syncdb

# マイグレーション履歴の確認
python manage.py showmigrations
```

---

## セキュリティの強化

### ファイアウォールの設定

```bash
# UFWの有効化
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 8000/tcp
sudo ufw enable
sudo ufw status
```

### SECRET_KEYの生成

```python
# Pythonで新しいSECRET_KEYを生成
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

### 環境変数の保護

```bash
# .envファイルのパーミッション設定
chmod 600 .env

# .gitignoreに追加（Git使用時）
echo ".env" >> .gitignore
```

---

## バックアップとリストア

### データベースのバックアップ

```bash
# バックアップの作成
sudo -u postgres pg_dump demo_app > ~/demo_app_backup_$(date +%Y%m%d).sql

# リストア
sudo -u postgres psql demo_app < ~/demo_app_backup_20251115.sql
```

---

## 環境のクリーンアップ

```bash
# アプリケーションの停止
sudo systemctl stop demo-app
sudo systemctl stop nginx

# データベースの削除
sudo -u postgres psql
DROP DATABASE demo_app;
DROP USER demo_user;
\q

# Instana Agentのアンインストール
sudo systemctl stop instana-agent
sudo apt remove --purge instana-agent

# ファイルの削除
rm -rf ~/demo/wrong-is-new-down-demo
```

---

## 次のステップ

セットアップが完了したら、[README.md](README.md)の「デモ実施手順」に従ってデモを実行してください。

## サポート

問題が発生した場合は、以下を確認してください：
1. [README.md](README.md)のトラブルシューティングセクション
2. Djangoのログ: `python manage.py runserver --traceback`
3. PostgreSQLのログ: `sudo journalctl -u postgresql -f`
4. Instanaのログ: `sudo journalctl -u instana-agent -f`
