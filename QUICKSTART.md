# クイックスタートガイド

AWS EC2（Ubuntu）で「Wrong is the new Down」デモを最速でセットアップする手順です。

---

## 所要時間
- **自動セットアップ**: 約10分
- **手動設定**: 約5分
- **合計**: 約15分

---

## 前提条件チェックリスト

### AWS EC2インスタンス
- [ ] Ubuntu 22.04 LTS
- [ ] t3.medium以上（2vCPU, 4GB RAM）
- [ ] 20GB以上のストレージ
- [ ] セキュリティグループで以下を開放:
  - [ ] 22番ポート（SSH）
  - [ ] 8000番ポート（HTTP）
  - [ ] 80番ポート（HTTP、オプション）

### IBM Instana
- [ ] Instana Agent Key を取得済み
- [ ] Instana Endpoint URL を取得済み

---

## セットアップ手順

### Step 1: EC2に接続
```bash
ssh -i your-key.pem ubuntu@<EC2-PUBLIC-IP>
```

### Step 2: リポジトリのクローンまたはファイルのアップロード

**Option A: Gitリポジトリからクローン（推奨）**
```bash
git clone https://github.com/your-org/wrong-is-new-down-demo.git
cd wrong-is-new-down-demo
```

**Option B: ファイルを手動でアップロード**
```bash
# ローカルマシンから
scp -i your-key.pem -r wrong-is-new-down-demo ubuntu@<EC2-PUBLIC-IP>:~/

# EC2で
cd ~/wrong-is-new-down-demo
```

### Step 3: 自動セットアップスクリプトの実行
```bash
chmod +x setup_ec2.sh
sudo ./setup_ec2.sh
```

**実行内容:**
- システムパッケージの更新
- Python、PostgreSQLのインストール
- データベースとユーザーの作成
- Python仮想環境の作成
- 依存パッケージのインストール
- ファイアウォールの設定

### Step 4: 環境変数ファイルの作成
```bash
cd demo_app
cp .env.example .env
vim .env  # または nano .env
```

**最低限の設定:**
```bash
DEBUG=True
SECRET_KEY=django-insecure-demo-key-CHANGE-THIS
DATABASE_NAME=demo_app
DATABASE_USER=demo_user
DATABASE_PASSWORD=demo_password_123
DATABASE_HOST=localhost
DATABASE_PORT=5432
ALLOWED_HOSTS=*
USE_CUSTOM_ERROR_HANDLER=False
```

### Step 5: IBM Instana Agentのインストール
```bash
# 環境変数の設定
export INSTANA_AGENT_KEY="your-agent-key-here"
export INSTANA_AGENT_ENDPOINT="your-endpoint-url"

# Agentインストール
curl -o setup_agent.sh https://setup.instana.io/agent
chmod 700 ./setup_agent.sh
sudo ./setup_agent.sh -a $INSTANA_AGENT_KEY -t dynamic -e $INSTANA_AGENT_ENDPOINT

# ステータス確認
sudo systemctl status instana-agent
```

### Step 6: データベースマイグレーション
```bash
cd ~/wrong-is-new-down-demo/demo_app
source ../venv/bin/activate
python manage.py migrate
```

### Step 7: アプリケーションの起動
```bash
python manage.py runserver 0.0.0.0:8000
```

### Step 8: 動作確認
```bash
# 別のターミナルで
curl http://localhost:8000/health/

# ブラウザで
http://<EC2-PUBLIC-IP>:8000/login/
```

---

## デモの実行

### デモ1: 問題版（Before）- HTTP 302

```bash
# ターミナル1: アプリケーションを停止（Ctrl+C）

# ターミナル2: 問題版に切り替え
cd ~/wrong-is-new-down-demo/scripts
./switch_to_problem.sh
./break_database.sh

# ターミナル1: アプリケーション再起動
cd ~/wrong-is-new-down-demo/demo_app
python manage.py runserver 0.0.0.0:8000

# ブラウザでログインを試みる
# → HTTP 302が返る
# → Instanaは「正常」と判断（問題！）
```

### デモ2: 修正版（After）- HTTP 500

```bash
# ターミナル2: 修正版に切り替え
cd ~/wrong-is-new-down-demo/scripts
./switch_to_fixed.sh

# ターミナル1: アプリケーション再起動（Ctrl+C → 再実行）
python manage.py runserver 0.0.0.0:8000

# ブラウザでログインを試みる
# → HTTP 500が返る
# → Instanaが正しくエラーを検知（修正成功！）
```

### デモ3: 正常動作の確認

```bash
# ターミナル2: データベース修復
cd ~/wrong-is-new-down-demo/scripts
./fix_database.sh

# ターミナル1: アプリケーション再起動
python manage.py runserver 0.0.0.0:8000

# ブラウザでログイン
# → HTTP 200が返る
# → 正常にログイン成功
```

---

## トラブルシューティング

### PostgreSQLが起動しない
```bash
sudo systemctl status postgresql
sudo systemctl restart postgresql
sudo journalctl -u postgresql -n 50
```

### Pythonパッケージのインストールエラー
```bash
source ~/wrong-is-new-down-demo/venv/bin/activate
pip install --upgrade pip
pip install -r ~/wrong-is-new-down-demo/requirements.txt
```

### Instana Agentが起動しない
```bash
sudo systemctl status instana-agent
sudo journalctl -u instana-agent -n 50
sudo systemctl restart instana-agent
```

### ポート8000にアクセスできない
```bash
# ファイアウォール確認
sudo ufw status

# セキュリティグループ確認（AWS Console）
# インバウンドルール: 8000番ポート TCP 0.0.0.0/0
```

---

## 次のステップ

1. **詳細なドキュメント**
   - [README.md](README.md) - 全体概要
   - [SETUP.md](SETUP.md) - 詳細セットアップ手順
   - [docs/demo_scenario.md](docs/demo_scenario.md) - デモシナリオ
   - [docs/architecture.md](docs/architecture.md) - アーキテクチャ説明

2. **カスタマイズ**
   - ログイン画面のデザイン変更
   - 追加のエラーシナリオの実装
   - 他のデータベースエラーの再現

3. **本番環境への拡張**
   - Gunicorn + Nginxの設定
   - systemdサービス化
   - AWS RDSへの移行
   - SSL/TLS証明書の設定

---

## デモのポイント

| シナリオ | HTTPステータス | Instana判定 | アラート |
|---------|---------------|------------|---------|
| 問題版（Before） | 302 | 🔄 正常（青信号） | ❌ なし |
| 修正版（After） | 500 | ❌ エラー（赤信号） | ✅ あり |
| 正常動作 | 200 | 🟢 成功（緑信号） | - |

---

## よくある質問

### Q: 本番環境で使えますか？
A: このデモはデモ環境専用です。本番環境では適切なセキュリティ設定が必要です。

### Q: 他のデータベース（MySQL、Oracle）でも動きますか？
A: はい。Djangoの設定を変更すれば対応可能です。

### Q: Dockerで動かせますか？
A: はい。Dockerfileとdocker-compose.ymlを追加すれば可能です。

### Q: Windows/Macでも動きますか？
A: はい。PostgreSQLとPythonがあれば動作します。

---

## サポート

問題が発生した場合：
1. [SETUP.md](SETUP.md)のトラブルシューティングセクションを確認
2. GitHubのIssueを作成

---

**作成日**: 2025年11月15日  
**対象**: AWS EC2（Ubuntu 22.04 LTS）  
**目的**: AI時代に向けた若手技術者の挑戦セッション用デモ教材
