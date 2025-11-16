#!/bin/bash

##############################################################################
# データベース接続を壊すスクリプト
# 
# データベース名を意図的に変更して、接続エラーを発生させます。
# これにより「Wrong is the new Down」現象を再現できます。
##############################################################################

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}========================================${NC}"
echo -e "${RED}データベース接続を壊す${NC}"
echo -e "${RED}========================================${NC}"

# .envファイルのパス
ENV_FILE="../demo_app/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}エラー: .envファイルが見つかりません${NC}"
    echo -e "${BLUE}パス: $ENV_FILE${NC}"
    exit 1
fi

# 元のDATABASE_NAMEをバックアップ
if ! grep -q "DATABASE_NAME_BACKUP" "$ENV_FILE"; then
    CURRENT_DB_NAME=$(grep "^DATABASE_NAME=" "$ENV_FILE" | cut -d'=' -f2)
    echo "DATABASE_NAME_BACKUP=$CURRENT_DB_NAME" >> "$ENV_FILE"
    echo -e "${GREEN}✓ 元のデータベース名をバックアップしました: $CURRENT_DB_NAME${NC}"
fi

# DATABASE_NAMEを壊す
sed -i 's/^DATABASE_NAME=\([^_]*\)/DATABASE_NAME=wrong_\1/' "$ENV_FILE"

echo ""
echo -e "${BLUE}現在の設定:${NC}"
grep "^DATABASE_NAME=" "$ENV_FILE"

echo ""
echo -e "${RED}⚠️  データベース接続が壊れました${NC}"
echo ""
echo -e "${BLUE}効果:${NC}"
echo "- Djangoアプリケーションはデータベースに接続できません"
echo "- ログインを試みるとOperationalErrorが発生します"
echo "- カスタムError HandlerがHTTP 302を返します（問題版の場合）"
echo "- Instanaは「正常」と判断します（これが「Wrong is the new Down」！）"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo "1. 仮想環境をアクティベートしてください（まだの場合）:"
echo "   cd ../demo_app"
echo "   source ../venv/bin/activate"
echo ""
echo "2. アプリケーションを起動してください:"
echo "   python manage.py runserver 0.0.0.0:8000 --noreload"
echo ""
echo "   ※ --noreload オプションでマイグレーションチェックをスキップします"
echo "   ※ これによりDjango起動時のエラーを回避できます"
echo ""
echo "2. ブラウザでログインを試みてください"
echo "   http://<EC2-PUBLIC-IP>:8000/login/"
echo ""
echo "3. Instanaダッシュボードで確認してください"
echo "   - HTTPステータス: 302（問題版）または500（修正版）"
echo "   - ログ: ERRORが記録されている"
echo "   - アラート: 発火していない（問題版）または発火（修正版）"
echo ""
echo -e "${YELLOW}修復する場合は: ./fix_database.sh${NC}"
echo -e "${RED}========================================${NC}"
