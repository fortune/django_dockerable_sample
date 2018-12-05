#!/bin/bash

# コンテナ上において、Django アプリケーションの BASE ディレクトリをカレントにして実行すること！

set -e  # パイプやサブシェルで実行したコマンドが１つでもエラーになったら直ちにシェルを終了させる。

# コンテナ起動時に環境変数 DJANGO_SETTINGS_MODULE で使用する settings モジュール名を必ず指定する。
#
if [ "$DJANGO_SETTINGS_MODULE" = "" ]; then
    echo "Environment variabl \"DJANGO_SETTINGS_MODULE\" is required."
    exit 1
fi

# 環境変数 ENV により、uwsgi で HTTPS 接続を提供するか、Django 付属の runserver を実行するかを決定する。
#
if [ "$ENV" = "DEV" ]; then
    echo "Running in development mode"
    exec python manage.py runserver 0.0.0.0:8000 --settings="$DJANGO_SETTINGS_MODULE"
else
    echo "Running in production mode"
    exec uwsgi --https 0.0.0.0:443,/ssl/server.crt,/ssl/server.key \
               --module project.wsgi \
               --static-map /static=/app/static \
               --master --enable-threads
fi

