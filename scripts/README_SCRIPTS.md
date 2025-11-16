# 運用スクリプト使用ガイド

## 重要な前提条件

### 1. 仮想環境のアクティベート

**すべてのスクリプトを実行する前に、必ず仮想環境をアクティベートしてください。**

```bash
cd ~/wrong-is-new-down-demo/demo_app
source ../venv/bin/activate
```

ターミナルを閉じたり、新しいSSHセッションを開始した場合は、必ず再度アクティベートしてください。

**アクティベートされているかの確認方法:**
```bash
# プロンプトに (venv) が表示されているか確認
(venv) ubuntu@ip-xxx:~$  # ← これが表示されていればOK

# または
which python
# /home/ubuntu/wrong-is-new-down-demo/venv/bin/python と表示されればOK
```

### 2. データベース接続エラーとDjango起動の関係

**重要**: `break_database.sh`を実行すると、Django起動時にエラーが発生します。

```
django.db.utils.OperationalError: database "wrong_demo_app" does not exist
```

これは**正常な動作**です。デモシナリオでは以下のような流れになります：

#### デモの正しい流れ

**シナリオ1: 問題版（HTTP 302）**

1. **まず正常な状態でDjangoを起動**
   ```bash
   cd ~/wrong-is-new-down-demo/demo_app
   source ../venv/bin/activate
   python manage.py runserver 0.0.0.0:8000
   ```

2. **別のターミナルでカスタムエラーハンドラーを有効化**
   ```bash
   cd ~/wrong-is-new-down-demo/scripts
   ./switch_to_problem.sh
   ```

3. **Djangoを再起動** （Ctrl+C で停止後）
   ```bash
   python manage.py runserver 0.0.0.0:8000
   ```

4. **さらに別のターミナルでデータベースを壊す**
   ```bash
   cd ~/wrong-is-new-down-demo/scripts
   ./break_database.sh
   ```

5. **ブラウザでログインを試みる**
   - URL: `http://<EC2-PUBLIC-IP>:8000/login/`
   - ログインフォームに入力して送信
   - → HTTP 302が返る
   - → 監視ツールは「正常」と判断（問題！）

**注意**: Django自体は起動したままにしておく必要があります。`break_database.sh`の実行後に再起動すると、起動時エラーになります。

#### もしDjango起動時にエラーが出た場合

以下のオプションを使用してください：

```bash
# --noreload オプションでマイグレーションチェックをスキップ
python manage.py runserver 0.0.0.0:8000 --noreload
```

これでDjangoは起動しますが、ログインリクエスト時にデータベースエラーが発生します。

---

## スクリプト一覧

### switch_to_problem.sh
カスタムエラーハンドラーを有効化（HTTP 302を返す）

**実行前の確認:**
- [ ] 仮想環境がアクティベートされている
- [ ] Djangoアプリケーションは停止している

**使用方法:**
```bash
cd ~/wrong-is-new-down-demo/scripts
./switch_to_problem.sh
```

**実行後:**
```bash
cd ../demo_app
source ../venv/bin/activate  # 必要な場合
python manage.py runserver 0.0.0.0:8000
```

---

### switch_to_fixed.sh
Django標準エラーハンドリングに変更（HTTP 500を返す）

**実行前の確認:**
- [ ] 仮想環境がアクティベートされている
- [ ] Djangoアプリケーションは停止している

**使用方法:**
```bash
cd ~/wrong-is-new-down-demo/scripts
./switch_to_fixed.sh
```

**実行後:**
```bash
cd ../demo_app
source ../venv/bin/activate  # 必要な場合
python manage.py runserver 0.0.0.0:8000
```

---

### break_database.sh
データベース接続を壊す

**実行前の確認:**
- [ ] Djangoアプリケーションが**起動している**
- [ ] カスタムエラーハンドラーまたは標準ハンドラーが設定済み

**使用方法:**
```bash
# Django起動中に別のターミナルで実行
cd ~/wrong-is-new-down-demo/scripts
./break_database.sh
```

**実行後:**
- Djangoは**再起動しないでください**（起動時エラーになります）
- そのままブラウザでログインを試みてください
- もし再起動が必要な場合は `--noreload` オプションを使用

---

### fix_database.sh
データベース接続を修復

**実行前の確認:**
- [ ] データベースが壊れている状態

**使用方法:**
```bash
cd ~/wrong-is-new-down-demo/scripts
./fix_database.sh
```

**実行後:**
```bash
cd ../demo_app
source ../venv/bin/activate  # 必要な場合
python manage.py runserver 0.0.0.0:8000
```

---

## よくあるエラーと解決方法

### エラー1: `Command 'python' not found`

**原因:** 仮想環境がアクティベートされていない

**解決方法:**
```bash
cd ~/wrong-is-new-down-demo/demo_app
source ../venv/bin/activate
```

---

### エラー2: Django起動時に `database "wrong_demo_app" does not exist`

**原因:** `break_database.sh`実行後にDjangoを再起動した

**解決方法1:** `--noreload`オプションを使用
```bash
python manage.py runserver 0.0.0.0:8000 --noreload
```

**解決方法2:** データベースを修復してから起動
```bash
cd ../scripts
./fix_database.sh
cd ../demo_app
python manage.py runserver 0.0.0.0:8000
```

---

### エラー3: スクリプトが実行できない (`Permission denied`)

**原因:** 実行権限がない

**解決方法:**
```bash
chmod +x ~/wrong-is-new-down-demo/scripts/*.sh
```

---

## デモ実施の推奨手順

### 準備

1. **ターミナル1: Djangoアプリケーション用**
   ```bash
   cd ~/wrong-is-new-down-demo/demo_app
   source ../venv/bin/activate
   ```

2. **ターミナル2: スクリプト実行用**
   ```bash
   cd ~/wrong-is-new-down-demo/scripts
   ```

### 問題版デモ

**ターミナル2:**
```bash
./switch_to_problem.sh
```

**ターミナル1:**
```bash
python manage.py runserver 0.0.0.0:8000
```

**ターミナル2:**
```bash
./break_database.sh
```

**ブラウザ:**
- `http://<EC2-PUBLIC-IP>:8000/login/`
- ログイン試行 → HTTP 302

### 修正版デモ

**ターミナル1:** (Djangoを停止: Ctrl+C)

**ターミナル2:**
```bash
./switch_to_fixed.sh
```

**ターミナル1:**
```bash
python manage.py runserver 0.0.0.0:8000 --noreload
```

**ブラウザ:**
- `http://<EC2-PUBLIC-IP>:8000/login/`
- ログイン試行 → HTTP 500

### 正常動作確認

**ターミナル1:** (Djangoを停止: Ctrl+C)

**ターミナル2:**
```bash
./fix_database.sh
```

**ターミナル1:**
```bash
python manage.py runserver 0.0.0.0:8000
```

**ブラウザ:**
- `http://<EC2-PUBLIC-IP>:8000/login/`
- ログイン成功 → HTTP 200

---

## チェックリスト

デモ実施前に確認してください：

- [ ] 仮想環境がアクティベートされている
- [ ] .envファイルが存在し、DATABASE_NAME=demo_appになっている
- [ ] PostgreSQLが起動している
- [ ] データベース `demo_app` が存在する
- [ ] マイグレーションが完了している
- [ ] セキュリティグループで8000番ポートが開放されている
- [ ] 監視ツール（Instana等）のエージェントが起動している

---

このガイドに従えば、スムーズにデモを実施できます！
