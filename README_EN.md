# Wrong is the new Down - デモアプリケーション

システムは動いているが、結果が間違っている新現象「Wrong is the new Down」を再現するデモアプリケーションです。

## 概要

このDjangoアプリケーションは、3つのシナリオで動作します：

1. **正常モード（BEFORE問題発生前）**: システムが正しく動作（HTTP 200）
2. **問題モード（BEFORE問題版）**: データベースエラーが発生するがHTTP 302を返すため、監視ツールがエラーを見逃す
3. **修正モード（AFTER修正版）**: Django標準のエラーハンドリングでHTTP 500を返し、適切にエラーを検知

## 重要なコンセプト: 「Wrong is the new Down」

従来の監視は、システムの停止（"Down"）のみを検知していました。しかし、現代のアプリケーションでは、システムが動作しているにもかかわらず、誤った結果を返す（"Wrong"）という新しい課題があります。

このデモでは、カスタムエラーハンドリングが実際のエラーを監視ツールから隠してしまう様子を実演します。

## 技術アーキテクチャ

```
Djangoアプリケーション
├── settings.py (DATABASE_NAME: 常に 'demo_app')
├── 独自DBアクセスクラス (DB_NAME: 設定変更可能)
│   └── 問題モード: 'wrong_demo_app' (存在しないデータベース)
└── ログインビュー
    ├── BEFORE: try-except → HTTP 302リダイレクト
    └── AFTER: Django標準 → HTTP 500エラー
```

## 動作要件

- Ubuntu 22.04 LTS
- Python 3.10以上
- PostgreSQL 14以上
- IBM Instana Agent（オプション、完全な監視デモンストレーションのため）

## クイックスタート

詳細な15分セットアップ手順は `QUICKSTART.md` を参照してください。

## 詳細セットアップ

詳細なインストールと設定方法は `SETUP.md` を参照してください。

## シナリオの切り替え

```bash
# 正常モード (HTTP 200)
./scripts/switch_to_normal.sh

# 問題モード (HTTP 302 - 監視ツールがエラーを見逃す)
./scripts/switch_to_problem.sh

# 修正モード (HTTP 500 - 適切なエラー検知)
./scripts/switch_to_fixed.sh
```

## 実際のPoC事例

### 発見された問題

2025年9月9日のInstana検証中に、Djangoアプリケーションで以下の問題が発見されました：

- **ログ出力**: ERRORレベルで記録
- **HTTPステータス**: 302 (Found) - リダイレクト
- **Instana判定**: 正常動作として認識 ⚠️

### 根本原因

```python
# 問題のあるコード実装
def catch_db_error(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except (DatabaseError, OperationalError):
            # 500エラーなのにリダイレクト（302）を返す
            return redirect('/app_folder/err_500/')
    return wrapper
```

### 問題点

1. **HTTPプロトコル違反**: エラー状況にも関わらず302（リダイレクト）を返却
2. **フレームワーク設計無視**: Djangoの標準エラーハンドリングを使用せず独自実装
3. **監視システム阻害**: APMツールが適切にエラーを検知できない
4. **デバッグ困難**: 本当のエラー原因がHTTPレベルで隠蔽される

### 改善提案の実装

```python
# Django標準機能を使った正しい実装
from django.http import HttpResponseServerError

def catch_db_error(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except (DatabaseError, OperationalError) as e:
            logger.error(f"データベースエラー: {e}")
            return HttpResponseServerError(
                render(args[0], '500.html').content
            )
    return wrapper
```

## ライセンス

このアプリケーションは教育・デモンストレーション目的で提供されています。

## 免責事項

このアプリケーションはデモンストレーションおよび教育目的でのみ提供されています。本番環境以外での使用を前提としており、自己責任でご利用ください。
