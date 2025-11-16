#!/bin/bash

##############################################################################
# Wrong is the new Down - EC2 自動セットアップスクリプト
# 
# このスクリプトは、AWS EC2 Ubuntu環境にデモアプリケーションを
# 自動的にセットアップします。
#
# 使用方法:
#   chmod +x setup_ec2.sh
#   sudo ./setup_ec2.sh
#
# 作成日: 2025年11月15日
##############################################################################

set -e  # エラーが発生したら即座に終了

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ログ関数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# rootチェック
if [ "$EUID" -ne 0 ]; then 
    log_error "このスクリプトはroot権限で実行してください"
    log_info "実行例: sudo ./setup_ec2.sh"
    exit 1
fi

# スクリプト開始
log_info "=========================================="
log_info "Wrong is the new Down デモアプリセットアップ"
log_info "=========================================="

# Step 1: システムの更新
log_info "Step 1: システムパッケージの更新中..."
apt update && apt upgrade -y
log_success "システムパッケージの更新完了"

# Step 2: 基本パッケージのインストール
log_info "Step 2: 基本パッケージのインストール中..."
apt install -y \
    git \
    curl \
    wget \
    vim \
    build-essential \
    python3 \
    python3-pip \
    python3-venv \
    software-properties-common
log_success "基本パッケージのインストール完了"

# Step 3: PostgreSQLのインストール
log_info "Step 3: PostgreSQLのインストール中..."
apt install -y postgresql postgresql-contrib
systemctl start postgresql
systemctl enable postgresql
log_success "PostgreSQLのインストール完了"

# Step 4: データベースとユーザーの作成
log_info "Step 4: データベースとユーザーの作成中..."
sudo -u postgres psql << EOF
-- データベースの存在確認と作成
SELECT 'CREATE DATABASE demo_app'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'demo_app')\gexec

-- ユーザーの存在確認と作成
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'demo_user') THEN
    CREATE USER demo_user WITH PASSWORD 'demo_password_123';
  END IF;
END
\$\$;

-- ユーザー設定
ALTER ROLE demo_user SET client_encoding TO 'utf8';
ALTER ROLE demo_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE demo_user SET timezone TO 'Asia/Tokyo';

-- 権限の付与
GRANT ALL PRIVILEGES ON DATABASE demo_app TO demo_user;

-- スキーマ権限の付与
\c demo_app
GRANT ALL ON SCHEMA public TO demo_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO demo_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO demo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO demo_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO demo_user;
EOF

log_success "データベースとユーザーの作成完了"

# Step 5: 環境変数の設定
log_info "Step 5: 環境変数の設定中..."
DEMO_USER="ubuntu"
DEMO_HOME="/home/$DEMO_USER"
DEMO_DIR="$DEMO_HOME/wrong-is-new-down-demo"

# Note: ZIPファイルを解凍すると自動的にwrong-is-new-down-demo/ディレクトリが作成されます
log_success "想定ディレクトリ: $DEMO_DIR"

# Step 6: Python仮想環境の作成
log_info "Step 6: Python仮想環境の作成中..."
sudo -u $DEMO_USER python3 -m venv "$DEMO_DIR/venv"
log_success "Python仮想環境の作成完了"

# Step 7: 依存パッケージのインストール準備
log_info "Step 7: requirements.txtの配置確認..."
if [ ! -f "$DEMO_DIR/requirements.txt" ]; then
    log_warning "requirements.txtが見つかりません"
    log_info "手動でrequirements.txtを配置してから以下を実行してください:"
    echo ""
    echo "  cd $DEMO_DIR"
    echo "  source venv/bin/activate"
    echo "  pip install -r requirements.txt"
    echo ""
else
    log_info "依存パッケージのインストール中..."
    sudo -u $DEMO_USER bash << EOF
source "$DEMO_DIR/venv/bin/activate"
pip install --upgrade pip
pip install -r "$DEMO_DIR/requirements.txt"
EOF
    log_success "依存パッケージのインストール完了"
fi

# Step 8: ファイアウォール設定
log_info "Step 8: ファイアウォール設定中..."
ufw --force enable
ufw allow 22/tcp    # SSH
ufw allow 80/tcp    # HTTP
ufw allow 8000/tcp  # Django Dev Server
log_success "ファイアウォール設定完了"

# Step 9: セットアップ完了メッセージ
log_success "=========================================="
log_success "セットアップが完了しました！"
log_success "=========================================="

echo ""
log_info "次のステップ:"
echo ""
echo "1. ZIPファイルをホームディレクトリに配置して解凍してください:"
echo "   cd $DEMO_HOME"
echo "   unzip wrong-is-new-down-demo.zip"
echo "   # これで $DEMO_DIR/ が作成されます"
echo ""
echo "2. 環境変数ファイル (.env) を作成してください:"
echo "   cd $DEMO_DIR/demo_app"
echo "   vim .env"
echo ""
echo "3. IBM Instana Agentをインストールしてください:"
echo "   export INSTANA_AGENT_KEY=\"your-agent-key\""
echo "   export INSTANA_AGENT_ENDPOINT=\"your-endpoint\""
echo "   curl -o setup_agent.sh https://setup.instana.io/agent"
echo "   chmod 700 ./setup_agent.sh"
echo "   sudo ./setup_agent.sh -a \$INSTANA_AGENT_KEY -t dynamic -e \$INSTANA_AGENT_ENDPOINT"
echo ""
echo "4. データベースマイグレーションを実行してください:"
echo "   cd $DEMO_DIR/demo_app"
echo "   source ../venv/bin/activate"
echo "   python manage.py migrate"
echo ""
echo "5. アプリケーションを起動してください:"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""

log_info "詳細な手順はSETUP.mdを参照してください"

# データベース接続情報の表示
echo ""
log_info "データベース接続情報:"
echo "  Database: demo_app"
echo "  User: demo_user"
echo "  Password: demo_password_123"
echo "  Host: localhost"
echo "  Port: 5432"
echo ""

log_warning "本番環境では必ずパスワードを変更してください！"

exit 0
