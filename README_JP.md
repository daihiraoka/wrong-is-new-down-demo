# Wrong is the new Down - デモアプリケーション

## 概要

このデモアプリケーションは、「Wrong is the new Down」現象を再現します。システムは動作していますが、結果が間違っており、監視ツールがそれを見逃してしまう問題を実演します。

## 「Wrong is the new Down」とは？

従来の監視は、システムの停止（Down）のみを検知していました。しかし、現代のアプリケーションでは、システムは動作しているが結果が間違っている（Wrong）という新しい問題が発生します。このデモでは、カスタムエラーハンドリングが実際のエラーを監視ツールから隠してしまう様子を示します。

## 実証する3つのシナリオ

### 1. 正常モード（BEFORE問題発生前）
- システム正常動作（HTTP 200）
- データベース接続成功
- 監視ツールも正常を表示

### 2. 問題モード（BEFORE問題版）
- データベースエラー発生
- カスタムエラーハンドラーがHTTP 302（リダイレクト）を返す
- 監視ツール（Instana）が「正常」と誤判定 ⚠️
- **これが「Wrong is the new Down」現象！**

### 3. 修正モード（AFTER修正版）
- Django標準エラーハンドリングを使用
- エラー発生時にHTTP 500を返す
- 監視ツールが正しくエラーを検知 ✅

## 技術アーキテクチャ

```
Djangoアプリケーション
├── settings.py (DATABASE_NAME: 常に 'demo_app')
├── 独自DBアクセスクラス (DB_NAME: 設定変更可能)
│   └── 問題モード: 'wrong_demo_app' (存在しないDB)
└── ログインビュー
    ├── BEFORE版: try-except → HTTP 302リダイレクト
    └── AFTER版: Django標準 → HTTP 500エラー
```

## システム要件

- Ubuntu 22.04 LTS
- Python 3.10以上
- PostgreSQL 14以上
- IBM Instanaエージェント（任意、完全なデモには推奨）

## クイックスタート

詳細は `クイックスタート.md` を参照してください（15分でセットアップ完了）。

## 詳細セットアップ

詳細なインストール手順は `セットアップ手順.md` を参照してください。

## シナリオの切り替え

```bash
# 正常モード（HTTP 200）
./scripts/switch_to_normal.sh

# 問題モード（HTTP 302 - 監視ツールが見逃す）
./scripts/switch_to_problem.sh

# 修正モード（HTTP 500 - 正しいエラー検知）
./scripts/switch_to_fixed.sh
```

## 実際のPoC事例

このデモは、2025年9月9日に実施されたInstana検証で発見された実際の問題に基づいています。

### 発見された問題
- アプリケーション: Django POST `/app_folder/C1_login`
- 症状: データベース接続エラー発生時に、ログにはERRORが記録されるが、HTTPレスポンスが302（リダイレクト）
- 結果: Instanaが正常動作として認識し、実際の障害が隠蔽される

### 原因コード
```python
def catch_db_error(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except (DatabaseError, OperationalError):
            return redirect('/app_folder/err_500/')  # 問題: HTTP 302
    return wrapper
```

### 修正コード
```python
def catch_db_error(func):
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except (DatabaseError, OperationalError) as e:
            logger.error(f"Database error: {e}")
            return HttpResponseServerError(
                render(args[0], '500.html').content
            )  # 修正: HTTP 500
    return wrapper
```

## ライセンス

このデモアプリケーションは教育目的で提供されています。

## 免責事項

本アプリケーションはデモンストレーションおよび教育目的でのみ提供されます。本番環境での使用は想定していません。使用は自己責任でお願いします。

## 活用シーン

1. **セッション後のハンズオン**: 参加者が実際にシナリオを体験
2. **顧客デモ**: 「Wrong is the new Down」現象を実演
3. **若手技術者教育**: 正しいエラーハンドリング手法の学習
4. **PoC検証**: 監視ツールの動作確認

## サポート

問題が発生した場合は、`トラブルシューティング.md` を参照してください。
