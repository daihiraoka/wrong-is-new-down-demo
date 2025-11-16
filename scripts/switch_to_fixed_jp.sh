#!/bin/bash

#######################################
# 修正モードに切り替え
# Django標準エラーハンドリング（HTTP 500）
#######################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEMO_APP_DIR="$PROJECT_DIR/demo_app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔵 修正モードに切り替え中（適切なエラーハンドリング）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 仮想環境が存在するか確認
if [ ! -d "$PROJECT_DIR/venv" ]; then
    echo "⚠️  仮想環境が見つかりません！"
    echo "   最初に setup_ec2.sh を実行してください"
    exit 1
fi

# 仮想環境有効化のリマインダー
if [ -z "$VIRTUAL_ENV" ]; then
    echo "⚠️  リマインダー: 最初に仮想環境を有効化してください！"
    echo "   実行: source venv/bin/activate"
    echo ""
fi

# ステップ1: 独自DB接続を正しいデータベース名に設定
echo "ステップ 1/4: 独自DB接続を正しいデータベースに設定中..."
cd "$DEMO_APP_DIR"
sed -i "s/DB_NAME = .*/DB_NAME = 'demo_app'  # 正しいデータベース名/" login_app/db_utils.py
echo "   ✅ 独自DB接続: demo_app"

# ステップ2: AFTER版ビューを使用（try-exceptなし）
echo "ステップ 2/4: AFTER版ビューを使用中（Django標準エラーハンドリング）..."
cp login_app/views_after.py login_app/views.py
echo "   ✅ ビュー: AFTER版（try-exceptなし、HTTP 500をエラー時に返します）"

# ステップ3: 本番環境エラーハンドリング用にDEBUG=Falseを設定
echo "ステップ 3/4: 本番環境エラーハンドリング用にDjangoを設定中..."
sed -i "s/DEBUG = .*/DEBUG = False/" config/settings.py
sed -i "s/ALLOWED_HOSTS = .*/ALLOWED_HOSTS = ['*']/" config/settings.py
echo "   ✅ Django DEBUG=False（本番環境モード）"

# ステップ4: Djangoサーバーを再起動
echo "ステップ 4/4: Djangoサーバーを再起動中..."
pkill -f "manage.py runserver" 2>/dev/null || true
sleep 2

if [ -n "$VIRTUAL_ENV" ]; then
    nohup python manage.py runserver 0.0.0.0:8000 --noreload > ../logs/server.log 2>&1 &
    sleep 3
    echo "   ✅ Djangoサーバーが再起動しました"
else
    echo "   ⚠️  サーバーが起動しませんでした（仮想環境が有効化されていません）"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 修正モードがアクティブ（適切なエラー検出）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "設定:"
echo "  Django settings.py DB:  demo_app"
echo "  独自DB接続:             demo_app ✅"
echo "  エラーハンドリング:     Django標準（try-exceptなし）"
echo "  DEBUG:                  False（本番環境モード）"
echo ""
echo "期待される動作:"
echo "  ✅ ログインは正常に成功"
echo "  ✅ データベースエラーが発生した場合: HTTP 500を返す"
echo "  ✅ 監視ツールはエラーを適切に検知"
echo "  ✅ 適切なアラートとインシデント対応"
echo ""
echo "エラーシナリオをテストするには:"
echo "  1. 実行: ./switch_to_problem_jp.sh"
echo "  2. その後実行: ./switch_to_fixed_jp.sh"
echo "  3. db_utils.pyのDB名を'wrong_demo_app'に変更"
echo "  4. テスト: curl -i -X POST http://localhost:8000/login/ ..."
echo "  5. HTTP 500レスポンスを確認（HTTP 302ではない）"
echo ""
