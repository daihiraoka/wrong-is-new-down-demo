#!/bin/bash

##############################################################################
# 問題版への切り替えスクリプト
# 
# カスタムError Handlerを有効化して、HTTP 302を返すようにします。
# これにより「Wrong is the new Down」現象が再現されます。
##############################################################################

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}問題版への切り替え${NC}"
echo -e "${YELLOW}========================================${NC}"

# .envファイルのパス
ENV_FILE="../demo_app/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}エラー: .envファイルが見つかりません${NC}"
    echo -e "${BLUE}パス: $ENV_FILE${NC}"
    exit 1
fi

# USE_CUSTOM_ERROR_HANDLER=Trueに設定
if grep -q "USE_CUSTOM_ERROR_HANDLER" "$ENV_FILE"; then
    # 既存の行を置き換え
    sed -i 's/USE_CUSTOM_ERROR_HANDLER=.*/USE_CUSTOM_ERROR_HANDLER=True/' "$ENV_FILE"
    echo -e "${GREEN}✓ USE_CUSTOM_ERROR_HANDLERをTrueに設定しました${NC}"
else
    # 行が存在しない場合は追加
    echo "USE_CUSTOM_ERROR_HANDLER=True" >> "$ENV_FILE"
    echo -e "${GREEN}✓ USE_CUSTOM_ERROR_HANDLERを追加しました${NC}"
fi

echo ""
echo -e "${BLUE}現在の設定:${NC}"
grep "USE_CUSTOM_ERROR_HANDLER" "$ENV_FILE"

echo ""
echo -e "${YELLOW}⚠️  カスタムError Handlerが有効化されました${NC}"
echo -e "${YELLOW}⚠️  エラー発生時にHTTP 302を返します${NC}"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo "1. アプリケーションを再起動してください"
echo "   cd ../demo_app"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""
echo "2. データベース接続を壊してください"
echo "   cd ../scripts"
echo "   ./break_database.sh"
echo ""
echo "3. ブラウザでログインを試みてください"
echo "   → HTTP 302が返ります"
echo "   → Instanaは「正常」と判断します（これが問題！）"
echo ""
echo -e "${GREEN}========================================${NC}"
