#!/bin/bash

##############################################################################
# データベース接続を修復するスクリプト
# 
# 壊したデータベース名を元に戻します。
##############################################################################

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}データベース接続を修復${NC}"
echo -e "${GREEN}========================================${NC}"

# .envファイルのパス
ENV_FILE="../demo_app/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}エラー: .envファイルが見つかりません${NC}"
    echo -e "${BLUE}パス: $ENV_FILE${NC}"
    exit 1
fi

# バックアップから復元
if grep -q "DATABASE_NAME_BACKUP" "$ENV_FILE"; then
    BACKUP_DB_NAME=$(grep "^DATABASE_NAME_BACKUP=" "$ENV_FILE" | cut -d'=' -f2)
    sed -i "s/^DATABASE_NAME=.*/DATABASE_NAME=$BACKUP_DB_NAME/" "$ENV_FILE"
    echo -e "${GREEN}✓ データベース名を復元しました: $BACKUP_DB_NAME${NC}"
    
    # バックアップ行を削除
    sed -i '/^DATABASE_NAME_BACKUP=/d' "$ENV_FILE"
else
    # バックアップがない場合はwrong_プレフィックスを削除
    sed -i 's/^DATABASE_NAME=wrong_/DATABASE_NAME=/' "$ENV_FILE"
    echo -e "${GREEN}✓ データベース名からwrong_プレフィックスを削除しました${NC}"
fi

echo ""
echo -e "${BLUE}現在の設定:${NC}"
grep "^DATABASE_NAME=" "$ENV_FILE"

echo ""
echo -e "${GREEN}✅ データベース接続が修復されました${NC}"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo "1. 仮想環境をアクティベートしてください（まだの場合）:"
echo "   cd ../demo_app"
echo "   source ../venv/bin/activate"
echo ""
echo "2. アプリケーションを再起動してください:"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""
echo "2. ブラウザでログインを試みてください"
echo "   → HTTP 200が返ります"
echo "   → 正常にログインできます"
echo ""
echo -e "${GREEN}========================================${NC}"
