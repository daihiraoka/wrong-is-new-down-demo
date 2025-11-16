"""
AFTER版: Django標準エラーハンドリング（HTTP 500）

この版は、正しいエラーハンドリングアプローチを示します。
データベースエラーが発生した際に、例外をキャッチせずにDjangoの
標準エラーハンドラーに伝播させるため、HTTP 500ステータスコードになります。

これが「修正された」シナリオです：
- データベースエラーは適切にHTTP 500として報告される
- 監視ツールはエラーを正しく識別できる
- 適切なアラートとインシデント対応が可能になる
"""

from django.http import HttpResponse
from django.shortcuts import render
from django.contrib.auth import authenticate
from .db_utils import DatabaseConnection
import psycopg2


def index_view(request):
    """ホームページビュー"""
    return render(request, 'login_app/index.html')


def login_view(request):
    """
    ログインビュー - Django標準エラーハンドリング（AFTER版）
    
    解決策: このビューはOperationalErrorをキャッチしません。
    例外はDjangoの標準エラーハンドラーに伝播され、HTTP 500を返します。
    """
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        # データベースエラーのtry-exceptなし！
        # Djangoの標準エラーハンドリングに任せます
        
        # 独自データベース接続クラスを使用
        conn = DatabaseConnection.get_connection()  # OperationalErrorを発生させる可能性
        cursor = conn.cursor()
        
        # データベースからユーザーを検索
        cursor.execute(
            "SELECT id, username, password FROM auth_user WHERE username = %s",
            [username]
        )
        user = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if user:
            # 実際のアプリケーションでは、パスワードハッシュを検証します
            # デモ目的では、ユーザーの存在のみをチェックします
            scenario = request.POST.get('scenario', 'after')
            context = {
                'username': username,
                'scenario': scenario
            }
            return render(request, 'login_app/index.html', context, status=200)
        else:
            context = {'error_message': 'ユーザー名またはパスワードが無効です'}
            return render(request, 'login_app/login.html', context, status=401)
            
    return render(request, 'login_app/login.html')


def custom_500_view(request):
    """
    カスタム500エラーページビュー
    
    AFTER版では、このビューは通常リダイレクト経由ではアクセスされません。
    Djangoの標準エラーハンドラーがtemplates/500.htmlを直接レンダリングします。
    このビューは互換性のために存在します。
    """
    return render(request, 'login_app/500.html', status=500)  # HTTP 500を返す
