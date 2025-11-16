# クイックスタートガイド（15分）

Ubuntu 22.04上で約15分でデモを起動できます。

## 前提条件

- Ubuntu 22.04 LTS環境
- rootまたはsudo権限
- インターネット接続

## 自動セットアップ

```bash
# 1. セットアップスクリプトをダウンロードして実行
curl -O https://raw.githubusercontent.com/YOUR_REPO/setup_ec2.sh
chmod +x setup_ec2.sh
sudo ./setup_ec2.sh

# 2. 仮想環境を有効化
cd ~/wrong-is-new-down-demo
source venv/bin/activate

# 3. Djangoマイグレーションを実行
python manage.py migrate

# 4. スーパーユーザーを作成
python manage.py createsuperuser

# 5. サーバーを起動
python manage.py runserver 0.0.0.0:8000 --noreload
```

## デモのテスト

### 1. 正常モード (HTTP 200)

```bash
# 正常モードに切り替え
./scripts/switch_to_normal.sh

# ログインをテスト
curl -X POST http://localhost:8000/login/ \
  -d "username=admin&password=yourpassword"

# 期待結果: HTTP 200 OK
```

### 2. 問題モード (HTTP 302)

```bash
# 問題モードに切り替え
./scripts/switch_to_problem.sh

# ログインをテスト
curl -i -X POST http://localhost:8000/login/ \
  -d "username=admin&password=yourpassword"

# 期待結果: HTTP 302 Found → /500.html
# これが「Wrong is the new Down」現象です！
```

### 3. 修正モード (HTTP 500)

```bash
# 修正モードに切り替え
./scripts/switch_to_fixed.sh

# ログインをテスト
curl -i -X POST http://localhost:8000/login/ \
  -d "username=admin&password=yourpassword"

# 期待結果: HTTP 500 Internal Server Error
# 監視ツールがエラーを正しく検知できます！
```

## 動作確認

ブラウザで以下にアクセス：
- `http://サーバーのIP:8000/`

ブラウザの開発者ツール（F12）を使用して、NetworkタブでHTTPステータスコードを確認してください。

## 次のステップ

- 詳細なアーキテクチャ説明は `SETUP.md` を参照
- 問題が発生した場合は `TROUBLESHOOTING.md` を参照
- Instanaエージェントを設定して完全な監視デモンストレーションを体験

## 注意事項

- **重要**: コマンドを実行する前に、必ず仮想環境を有効化してください：
  ```bash
  source venv/bin/activate
  ```

- Django起動時のデータベース接続チェックを防ぐため、`--noreload`オプションが必要です：
  ```bash
  python manage.py runserver 0.0.0.0:8000 --noreload
  ```
