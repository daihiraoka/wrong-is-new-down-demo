# アーキテクチャ説明

## システム全体構成

```
┌─────────────────────────────────────────────────────────────┐
│                        AWS EC2 Instance                      │
│                         (Ubuntu 22.04)                       │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │                Django Application                   │     │
│  │              (Port 8000 / Gunicorn)                │     │
│  │                                                     │     │
│  │  ┌──────────────────────────────────────────┐      │     │
│  │  │         Custom Error Handler              │      │     │
│  │  │      (Middleware - Conditional)          │      │     │
│  │  │                                          │      │     │
│  │  │  • USE_CUSTOM_ERROR_HANDLER=True         │      │     │
│  │  │    → Returns HTTP 302 on errors          │      │     │
│  │  │                                          │      │     │
│  │  │  • USE_CUSTOM_ERROR_HANDLER=False        │      │     │
│  │  │    → Returns HTTP 500 (Django default)   │      │     │
│  │  └──────────────────────────────────────────┘      │     │
│  │                        ↓                            │     │
│  │  ┌──────────────────────────────────────────┐      │     │
│  │  │            Login View                     │      │     │
│  │  │  • Accepts POST /login/submit/           │      │     │
│  │  │  • Queries PostgreSQL database           │      │     │
│  │  │  • Raises exception on DB error          │      │     │
│  │  └──────────────────────────────────────────┘      │     │
│  └────────────────────────────────────────────────────┘     │
│                          ↓                                   │
│  ┌────────────────────────────────────────────────────┐     │
│  │              PostgreSQL Database                    │     │
│  │                (Port 5432)                         │     │
│  │                                                     │     │
│  │  Database: demo_app / wrong_demo_app (broken)      │     │
│  │  User: demo_user                                   │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │              IBM Instana Agent                      │     │
│  │           (Observability & Monitoring)             │     │
│  │                                                     │     │
│  │  • Traces HTTP requests                            │     │
│  │  • Monitors response codes                         │     │
│  │  • Captures logs and errors                        │     │
│  │  • Sends data to Instana Backend                   │     │
│  └────────────────────────────────────────────────────┘     │
│                          ↑                                   │
└──────────────────────────┼───────────────────────────────────┘
                           │
                           ↓
              ┌────────────────────────┐
              │  Instana Backend       │
              │  (SaaS / On-premise)  │
              │                        │
              │  • Dashboard           │
              │  • Alerting            │
              │  • Analytics           │
              └────────────────────────┘
```

---

## リクエストフロー

### 正常フロー（データベース接続正常）

```
1. User → Browser
   POST /login/submit/ (username, password)
   
2. Browser → Django
   HTTP POST request
   
3. Django → PostgreSQL
   SELECT query to verify user
   
4. PostgreSQL → Django
   User data returned
   
5. Django → Browser
   HTTP 200 OK + JSON response
   {"status": "success", "message": "Login successful"}
   
6. Instana Agent → Instana Backend
   Trace: POST /login/submit/ | Status: 200 | Duration: ~50ms
   Judgment: ✅ Success (Green)
```

---

### 問題版フロー（データベース接続エラー + カスタムHandler有効）

```
1. User → Browser
   POST /login/submit/ (username, password)
   
2. Browser → Django
   HTTP POST request
   
3. Django → PostgreSQL
   SELECT query to verify user
   
4. PostgreSQL → Django
   ❌ OperationalError: database "wrong_demo_app" does not exist
   
5. Django raises Exception
   ↓
6. CustomErrorHandlerMiddleware catches exception
   ↓
   Logs: ERROR - Database error during login
   ↓
   Returns: HTTP 302 Redirect to /login/
   
7. Django → Browser
   HTTP 302 Found
   Location: /login/
   
8. Browser automatically follows redirect
   → Displays login page again
   → User sees NO ERROR MESSAGE (appears normal)
   
9. Instana Agent → Instana Backend
   Trace: POST /login/submit/ | Status: 302 | Duration: ~30ms
   Judgment: 🔄 Normal Redirect (Blue) - NO ALERT! ⚠️
   
   ❌ PROBLEM: Instana thinks this is normal!
   ✅ BUT: Logs show ERROR
```

**これが「Wrong is the new Down」現象！**

---

### 修正版フロー（データベース接続エラー + カスタムHandler無効）

```
1. User → Browser
   POST /login/submit/ (username, password)
   
2. Browser → Django
   HTTP POST request
   
3. Django → PostgreSQL
   SELECT query to verify user
   
4. PostgreSQL → Django
   ❌ OperationalError: database "wrong_demo_app" does not exist
   
5. Django raises Exception
   ↓
6. CustomErrorHandlerMiddleware is DISABLED
   ↓
   Django's default error handling
   ↓
   Returns: HTTP 500 Internal Server Error
   
7. Django → Browser
   HTTP 500 Internal Server Error
   Error page displayed
   
8. Browser displays error
   → User sees ERROR MESSAGE (clear indication of problem)
   
9. Instana Agent → Instana Backend
   Trace: POST /login/submit/ | Status: 500 | Duration: ~30ms
   Judgment: ❌ Error (Red) - ALERT TRIGGERED! ✅
   
   ✅ CORRECT: Instana detects the error!
   ✅ Alert is fired
   ✅ Operations team is notified
```

**これが修正後の正しい動作！**

---

## コンポーネント詳細

### 1. Djangoアプリケーション

#### settings.py
```python
# Key configuration
USE_CUSTOM_ERROR_HANDLER = config('USE_CUSTOM_ERROR_HANDLER', default=False, cast=bool)

MIDDLEWARE = [
    # ... other middleware
    'login_app.middleware.CustomErrorHandlerMiddleware',  # ← The key component
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DATABASE_NAME', default='demo_app'),  # ← Can be changed to 'wrong_demo_app'
        'USER': config('DATABASE_USER', default='demo_user'),
        'PASSWORD': config('DATABASE_PASSWORD', default='demo_password_123'),
        'HOST': config('DATABASE_HOST', default='localhost'),
        'PORT': config('DATABASE_PORT', default='5432'),
    }
}
```

#### middleware.py (CustomErrorHandlerMiddleware)
```python
def process_exception(self, request, exception):
    if not self.enabled:
        return None  # Django handles error → HTTP 500
    
    # THIS IS THE PROBLEM!
    logger.error(f"Exception: {str(exception)}")
    return HttpResponseRedirect(reverse('login_page'))  # → HTTP 302
```

**動作モード:**
- `USE_CUSTOM_ERROR_HANDLER=True` → HTTP 302を返す（問題版）
- `USE_CUSTOM_ERROR_HANDLER=False` → HTTP 500を返す（修正版）

#### views.py (login_submit)
```python
@csrf_exempt
def login_submit(request):
    try:
        # Database query
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 FROM auth_user WHERE username = %s", [username])
            result = cursor.fetchone()
        
        # Success
        return JsonResponse({'status': 'success'}, status=200)
    
    except Exception as e:
        # Error occurs here
        logger.error(f"Database error: {str(e)}")
        raise  # Re-raise → Middleware catches it
```

---

### 2. PostgreSQL データベース

#### 正常状態
```sql
Database: demo_app
User: demo_user
Tables: auth_user, ...
```

#### 障害状態
```sql
Database: wrong_demo_app (Does NOT exist)
User: demo_user
→ OperationalError: database "wrong_demo_app" does not exist
```

**切り替え方法:**
- `break_database.sh` → `DATABASE_NAME=wrong_demo_app`
- `fix_database.sh` → `DATABASE_NAME=demo_app`

---

### 3. IBM Instana Agent

#### 役割
1. **トレース収集**: HTTP リクエスト/レスポンスを監視
2. **メトリクス収集**: CPU、メモリ、ネットワーク等
3. **ログ収集**: アプリケーションログ
4. **自動計装**: Djangoアプリケーションを自動的に監視

#### 判定ロジック
```
HTTP Status Code → Judgment
─────────────────────────────
200-299 (2xx)   → ✅ Success (Green)
300-399 (3xx)   → 🔄 Redirect (Blue) - Considered "Normal"
400-499 (4xx)   → ⚠️  Client Error (Yellow)
500-599 (5xx)   → ❌ Server Error (Red) - Triggers Alert
```

**問題点:**
- HTTP 302は「正常なリダイレクト」と判断される
- ログに`ERROR`があっても、HTTPステータスが優先される
- アラートは HTTPステータス基準で発火する

---

## 信号機メタファー

| HTTPステータス | 信号 | 意味 | Instana判定 | アラート |
|---------------|------|------|------------|---------|
| 🟢 200番台 | 緑信号 | 成功 | Success | なし |
| 🔄 300番台 | 青信号 | リダイレクト | Normal | **なし（問題！）** |
| ❌ 500番台 | 赤信号 | エラー | Error | **あり（正しい）** |

---

## データフロー比較

### 問題版（HTTP 302）
```
User Input → Django → DB Error → Middleware → HTTP 302
                                     ↓
                                  Instana: 🔄 "Normal"
                                     ↓
                                  No Alert ❌
```

### 修正版（HTTP 500）
```
User Input → Django → DB Error → Django Default → HTTP 500
                                         ↓
                                    Instana: ❌ "Error"
                                         ↓
                                    Alert Fired ✅
```

---

## セキュリティ考慮事項

### 1. 環境変数管理
- `.env`ファイルでシークレット情報を管理
- Git管理対象外（`.gitignore`に追加）
- 本番環境では必ず変更すること

### 2. データベース認証
- デフォルトパスワードは`demo_password_123`
- 本番環境では強力なパスワードを使用

### 3. Django SECRET_KEY
- デフォルトは開発用
- 本番環境では`get_random_secret_key()`で生成

### 4. ファイアウォール
```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 8000/tcp  # Django Dev Server
```

---

## スケーラビリティ

### 現在の構成（デモ用）
- Single EC2 instance
- Django development server
- PostgreSQL on same instance

### 本番環境への拡張
1. **アプリケーション層**
   - Gunicorn/uWSGI
   - Nginx reverse proxy
   - Auto Scaling Group

2. **データベース層**
   - AWS RDS for PostgreSQL
   - Read replicas
   - Automated backups

3. **監視層**
   - Instana APM
   - CloudWatch Logs
   - CloudWatch Metrics

---

## 技術スタック詳細

### Backend
- **Django 4.2**: Web framework
- **Python 3.9+**: Programming language
- **psycopg2**: PostgreSQL adapter
- **python-decouple**: Environment variable management

### Database
- **PostgreSQL 14+**: Relational database

### Monitoring
- **IBM Instana**: Application Performance Monitoring
  - Auto-instrumentation
  - Distributed tracing
  - Real-time alerting

### Infrastructure
- **AWS EC2**: Compute instance
- **Ubuntu 22.04 LTS**: Operating system
- **UFW**: Firewall

---

## パフォーマンス特性

### 正常時
- **レスポンスタイム**: ~50ms
- **HTTPステータス**: 200
- **データベースクエリ**: 1クエリ

### エラー時（問題版）
- **レスポンスタイム**: ~30ms（短い！リダイレクトのみ）
- **HTTPステータス**: 302
- **ログ**: ERROR記録あり
- **Instanaアラート**: なし ❌

### エラー時（修正版）
- **レスポンスタイム**: ~30ms
- **HTTPステータス**: 500
- **ログ**: ERROR記録あり
- **Instanaアラート**: あり ✅

---

## まとめ

このアーキテクチャは、「Wrong is the new Down」現象を
シンプルかつ効果的に再現できるように設計されています。

**キーポイント:**
1. カスタムError Handlerのオン/オフで問題を再現・修正
2. 実際のPoC事例に基づいた現実的なシナリオ
3. Instanaによる可観測性の重要性を実演
4. 教育目的に最適化された構成

このデモを通じて、適切なHTTPステータスコードの返却が
いかに重要かを理解できます。
