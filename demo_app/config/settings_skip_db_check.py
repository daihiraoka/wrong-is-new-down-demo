"""
Django settings for Wrong is the new Down demo project.
DB connection check を回避するための設定
"""

from .settings import *

# データベース接続チェックをスキップ
# これにより、wrong_demo_appが存在しなくてもrunserverが起動可能
DATABASES['default']['OPTIONS'] = {
    'connect_timeout': 1,
}

# マイグレーションチェックを無効化
MIGRATION_MODULES = {app: None for app in INSTALLED_APPS}
