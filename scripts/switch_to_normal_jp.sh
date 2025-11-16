#!/bin/bash

#######################################
# 正常モードに切り替え
# システムが正しく動作（HTTP 200）
#######################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DEMO_APP_DIR="$PROJECT_DIR/demo_app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢 正常モードに切り替え中"
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
echo "ステップ 1/3: 独自DB接続を正しいデータベースに設定中..."
cd "$DEMO_APP_DIR"
sed -i "s/DB_NAME = .*/DB_NAME = 'demo_app'  # 正しいデータベース名/" login_app/db_utils.py
echo "   ✅ 独自DB接続: demo_app"

# ステップ2: BEFORE版ビューを使用（try-exceptあり、ただし起動しない）
echo "ステップ 2/3: BEFORE版ビューを使用中（try-except休止中）..."
cp login_app/views_before.py login_app/views.py
echo "   ✅ ビュー: BEFORE版（try-exceptハンドラーあり）"

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
echo "✅ 正常モードがアクティブ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "設定:"
echo "  Django settings.py DB:  demo_app"
echo "  独自DB接続:             demo_app ✅"
echo "  エラーハンドリング:     try-except（休止中 💤）"
echo ""
echo "期待される動作:"
echo "  ✅ ログイン成功"
echo "  ✅ HTTP 200 OK"
echo "  ✅ 監視ツールは正常動作を検知"
echo ""
echo "テスト方法:"
echo "  curl -X POST http://localhost:8000/login/ -d 'username=admin&password=yourpass'"
echo ""
