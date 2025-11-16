"""
BEFORE版: カスタムエラーハンドリング（HTTP 302）

この版は、問題のあるエラーハンドリングアプローチを示します。
データベースエラーが発生した際に、エラーをキャッチしてリダイレクトを返すため、
HTTP 302ステータスコードになります。

これが「Wrong is the new Down」シナリオです：
- システムは動作しているように見える（HTTP 302はエラーコードではない）
- 監視ツールはリダイレクトを通常の動作として認識
- 実際のエラーが監視から隠される
"""

from django.http import HttpResponse, HttpResponseRedirect
from django.shortcuts import render
from django.contrib.auth import authenticate
from .db_utils import DatabaseConnection
import psycopg2


def index_view(request):
    """ホームページビュー"""
    return render(request, 'login_app/index.html')


def login_view(request):
    """
    ログインビュー - カスタムエラーハンドリング（BEFORE版）
    
    問題点: このビューはOperationalErrorをキャッチしてHTTP 302リダイレクトを返します。
    これにより、実際のエラーが監視ツールから隠されます。
    """
    if request.method == 'POST':
        username = request.POST.get('username')
        password = request.POST.get('password')
        
        try:
            # 独自データベース接続クラスを使用
            # この接続はDjangoのsettings.py設定とは独立しています
            conn = DatabaseConnection.get_connection()
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
                return HttpResponse(
                    "<h1>ログイン成功</h1><p>おかえりなさい！</p>",
                    status=200
                )
            else:
                return HttpResponse(
                    "<h1>ログイン失敗</h1><p>ユーザー名またはパスワードが無効です</p>",
                    status=401
                )
                
        except psycopg2.OperationalError as e:
            # 問題点: データベースエラーをキャッチしてエラーページにリダイレクト
            # これによりHTTP 302が返され、HTTP 500ではありません
            # 監視ツールはこれを「通常のリダイレクト」動作として認識します
            print(f"データベースエラーが発生しました: {e}")  # ログに記録
            return HttpResponseRedirect('/500.html')  # HTTP 302
        
        except Exception as e:
            # その他の例外もキャッチ
            print(f"予期しないエラーが発生しました: {e}")
            return HttpResponseRedirect('/500.html')  # HTTP 302
            
    return render(request, 'login_app/login.html')


def custom_500_view(request):
    """
    カスタム500エラーページビュー
    
    このビューはlogin_viewからのHTTP 302リダイレクト経由でアクセスされます。
    HTTP 200でエラーページコンテンツを返すため、さらにエラーを隠します。
    """
    return render(request, 'login_app/500.html', status=200)  # HTTP 200を返す！
