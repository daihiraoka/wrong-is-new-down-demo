#!/bin/bash

##############################################################################
# 修正版への切り替えスクリプト
# 
# カスタムError Handlerを無効化して、Django標準のHTTP 500を返すようにします。
# これによりInstanaが正しくエラーを検知できます。
##############################################################################

set -e

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}修正版への切り替え${NC}"
echo -e "${GREEN}========================================${NC}"

# .envファイルのパス
ENV_FILE="../demo_app/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}エラー: .envファイルが見つかりません${NC}"
    echo -e "${BLUE}パス: $ENV_FILE${NC}"
    exit 1
fi

# USE_CUSTOM_ERROR_HANDLER=Falseに設定
if grep -q "USE_CUSTOM_ERROR_HANDLER" "$ENV_FILE"; then
    # 既存の行を置き換え
    sed -i 's/USE_CUSTOM_ERROR_HANDLER=.*/USE_CUSTOM_ERROR_HANDLER=False/' "$ENV_FILE"
    echo -e "${GREEN}✓ USE_CUSTOM_ERROR_HANDLERをFalseに設定しました${NC}"
else
    # 行が存在しない場合は追加
    echo "USE_CUSTOM_ERROR_HANDLER=False" >> "$ENV_FILE"
    echo -e "${GREEN}✓ USE_CUSTOM_ERROR_HANDLERを追加しました${NC}"
fi

echo ""
echo -e "${BLUE}現在の設定:${NC}"
grep "USE_CUSTOM_ERROR_HANDLER" "$ENV_FILE"

echo ""
echo -e "${GREEN}✅ カスタムError Handlerが無効化されました${NC}"
echo -e "${GREEN}✅ エラー発生時にHTTP 500を返します${NC}"
echo ""
echo -e "${BLUE}次のステップ:${NC}"
echo "1. アプリケーションを再起動してください"
echo "   cd ../demo_app"
echo "   python manage.py runserver 0.0.0.0:8000"
echo ""
echo "2. ブラウザでログインを試みてください"
echo "   → HTTP 500が返ります"
echo "   → Instanaが正しくエラーを検知します（修正成功！）"
echo ""
echo "3. データベース接続を修復する場合は"
echo "   cd ../scripts"
echo "   ./fix_database.sh"
echo ""
echo -e "${GREEN}========================================${NC}"
