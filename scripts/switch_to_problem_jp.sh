#!/bin/bash

#######################################
# 問題モードに切り替え
# 「Wrong is the new Down」シナリオ
# データベースエラーがHTTP 302を返す
#######################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEMO_APP_DIR="$PROJECT_DIR/demo_app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 問題モードに切り替え中（Wrong is the new Down）"
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

# ステップ1: 独自DB接続を間違ったデータベース名に設定
echo "ステップ 1/3: 独自DB接続を間違ったデータベースに設定中..."
cd "$DEMO_APP_DIR"
sed -i "s/DB_NAME = .*/DB_NAME = 'wrong_demo_app'  # 間違ったデータベース名（存在しません）/" login_app/db_utils.py
echo "   ⚠️  独自DB接続: wrong_demo_app（存在しません）"

# ステップ2: BEFORE版ビューを使用（try-exceptあり、キャッチして起動）
echo "ステップ 2/3: BEFORE版ビューを使用中（try-exceptアクティブ）..."
cp login_app/views_before.py login_app/views.py
echo "   ⚠️  ビュー: BEFORE版（HTTP 302を返します）"

# ステップ3: Djangoサーバーを再起動
echo "ステップ 3/3: Djangoサーバーを再起動中..."
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
echo "⚠️  問題モードがアクティブ（Wrong is the new Down）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "設定:"
echo "  Django settings.py DB:  demo_app（変更なし）"
echo "  独自DB接続:             wrong_demo_app ❌（存在しません）"
echo "  エラーハンドリング:     try-except（アクティブ ⚡ → HTTP 302）"
echo ""
echo "期待される動作:"
echo "  ❌ データベース接続失敗"
echo "  ⚠️  HTTP 302を返す → /500.html"
echo "  ⚠️  /500.htmlはHTTP 200を返す"
echo "  ⚠️  監視ツールは「302→200」を正常と判定"
echo "  ❌ エラーが監視から隠されます！"
echo ""
echo "これが「Wrong is the new Down」現象です:"
echo "  - システムは動作している"
echo "  - ユーザーにはエラーページが表示される"
echo "  - しかし監視ツールはすべて正常と判断！"
echo ""
echo "テスト方法:"
echo "  curl -i -X POST http://localhost:8000/login/ -d 'username=admin&password=yourpass'"
echo "  （HTTP 302の後にHTTP 200が返されることを確認）"
echo ""
