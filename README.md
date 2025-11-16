# Wrong is the new Down - デモアプリケーション

## DISCLAIMER（免責事項）

このデモアプリケーションは教育・デモンストレーション目的で作成されています。

- 本番環境での使用は想定していません
- デフォルト認証情報は必ず変更してください
- 提供されるコードは「現状有姿」であり、いかなる保証もありません

## 概要
このデモアプリケーションは、「Wrong is the new Down」現象を再現するサンプルです。
システムは動いているが、結果が間違っている新しいタイプの障害を体験できます。

## 技術スタック
- OS: Ubuntu 20.04/22.04
- 言語: Python 3.9+
- フレームワーク: Django 4.2
- データベース: PostgreSQL 14+
- 監視: APM（Application Performance Monitoring）ツール

## 「Wrong is the new Down」とは？

従来の監視は「Down（停止）」のみを検知していましたが、
現代のシステムでは「Wrong（誤動作）」という新しい障害が発生します。

### この現象の特徴
- システムは動いている（HTTP 200/300番台を返す）
- しかし結果は間違っている（データベースエラー等が発生）
- 従来の監視ツールでは検知できない
- ログには「ERROR」が記録されるが、HTTPステータスが優先される

## デモシナリオ

### 問題版（Before）
1. ログイン画面にアクセス
2. データベース接続エラーが発生
3. カスタムError HandlerがHTTP 302を返す
4. 監視ツールは「正常」と判断（アラートなし）
5. しかしログには「ERROR」が記録されている

### 修正版（After）
1. Django標準エラーハンドリングに変更
2. データベース接続エラーが発生
3. HTTP 500を返す
4. 監視ツールが「エラー」を正しく検知（アラート発火）

## ディレクトリ構成
```
wrong-is-new-down-demo/
├── README.md                    # このファイル
├── SETUP.md                     # セットアップ手順
├── requirements.txt             # Python依存パッケージ
├── setup_ec2.sh                 # EC2初期セットアップスクリプト
├── demo_app/                    # Djangoアプリケーション
│   ├── manage.py
│   ├── config/                  # プロジェクト設定
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── wsgi.py
│   └── login_app/               # ログインアプリ
│       ├── views.py             # ビューロジック
│       ├── middleware.py        # エラーハンドラー
│       ├── urls.py
│       └── templates/
│           └── login.html       # ログイン画面
├── scripts/                     # 運用スクリプト
│   ├── switch_to_problem.sh     # 問題版に切り替え
│   ├── switch_to_fixed.sh       # 修正版に切り替え
│   ├── break_database.sh        # データベース接続を壊す
│   └── fix_database.sh          # データベース接続を修復
└── docs/                        # ドキュメント
    ├── demo_scenario.md         # デモシナリオ詳細
    └── architecture.md          # アーキテクチャ説明
```

## クイックスタート

### 1. EC2インスタンス準備
```bash
# Ubuntu 22.04 LTS
# t3.medium以上推奨
# セキュリティグループ: 8000番ポート開放
```

### 2. ファイルの配置と解凍
```bash
# ZIPファイルをEC2にアップロード後
cd ~
unzip wrong-is-new-down-demo.zip
cd wrong-is-new-down-demo

# セットアップスクリプトの実行
chmod +x setup_ec2.sh
sudo ./setup_ec2.sh
```

### 3. 監視エージェント設定
```bash
# 使用する監視ツールのエージェントをインストールしてください
# 詳細はSETUP.mdを参照
```

### 4. アプリケーション起動
```bash
cd demo_app
python manage.py migrate
python manage.py runserver 0.0.0.0:8000
```

### 5. ブラウザでアクセス
```
http://<EC2のパブリックIP>:8000/login/
```

## デモ実施手順

### Step 1: 問題版の動作確認
```bash
# 問題版に切り替え（カスタムError Handler有効化）
cd scripts
./switch_to_problem.sh

# データベース接続を壊す
./break_database.sh

# ブラウザでログインを試みる
# → HTTP 302が返る
# → 監視ツールで「正常」と表示される
# → しかしログには「ERROR」が記録されている
```

### Step 2: 監視ツールで確認
1. 監視ダッシュボードにアクセス
2. トレースを検索: `POST /login/`
3. HTTPステータス: 302 - Found
4. ログセクション: ERRORが記録されている
5. アラート: 発火していない（これが問題）

### Step 3: 修正版の動作確認
```bash
# 修正版に切り替え（Django標準エラーハンドリング）
./switch_to_fixed.sh

# アプリケーション再起動
cd ../demo_app
python manage.py runserver 0.0.0.0:8000

# ブラウザでログインを試みる
# → HTTP 500が返る
# → 監視ツールで「エラー」と表示される
```

### Step 4: 監視ツールで再確認
1. 監視ダッシュボードにアクセス
2. トレースを検索: `POST /login/`
3. HTTPステータス: 500 - Internal Server Error
4. アラート: 正しく発火している（修正成功）

### Step 5: データベース修復
```bash
# データベース接続を修復
./fix_database.sh

# 正常動作を確認
# → HTTP 200が返る
# → ログインが成功する
```

## HTTPステータスと監視判定

| HTTPステータス | 監視判定 |
|---------------|---------|
| 200番台 | 成功 |
| 300番台 | 正常（リダイレクト） |
| 500番台 | エラー |

問題: カスタムError Handlerが302を返すと、監視ツールは「正常」と判断してしまう

## 学習ポイント

### 1. エラーハンドリングの重要性
- カスタムエラーハンドラーは慎重に設計する
- HTTPステータスコードは監視ツールの判定基準になる
- 302は「正常なリダイレクト」として扱われる

### 2. 監視の限界
- HTTPステータスだけでは真の健全性は判断できない
- ログとメトリクスの両方を監視する必要がある
- アプリケーションレベルの可観測性が重要

### 3. AI時代の監視
- 従来: Down（停止）の検知
- 現在: Wrong（誤動作）の検知が必要
- 未来: AI/MLによる異常検知の進化

## トラブルシューティング

### 監視エージェントでトレースが見えない
```bash
# エージェントのステータス確認
sudo systemctl status <monitoring-agent>

# ログ確認
sudo journalctl -u <monitoring-agent> -f
```

### PostgreSQLに接続できない
```bash
# PostgreSQLのステータス確認
sudo systemctl status postgresql

# データベース存在確認
sudo -u postgres psql -l
```

### Djangoアプリが起動しない
```bash
# Python仮想環境の確認
source venv/bin/activate
pip list

# マイグレーション実行
python manage.py migrate

# エラーログ確認
python manage.py runserver --traceback
```

## 応用例

### 1. 教育・トレーニング
- 若手技術者向けハンズオン
- 可観測性の重要性を体験
- エラーハンドリングのベストプラクティス学習

### 2. 顧客デモ
- 監視ツールの価値提案
- 「Wrong is the new Down」のコンセプト説明
- リアルタイム問題検知のデモ

### 3. 品質保証
- テスト環境での検証
- エラーハンドリングの妥当性確認
- 監視ツールの動作確認

## 参考資料

- Django Error Handling Best Practices
- HTTP Status Codes
- Application Performance Monitoring

## ライセンス
MIT License

## 問い合わせ
GitHubのIssueでお問い合わせください

---
作成日: 2025年11月
バージョン: 1.0
目的: 教育・デモンストレーション用教材
