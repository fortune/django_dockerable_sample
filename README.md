# Dockerable Django Project

Django アプリケーションを Docker コンテナ上で動かすサンプル。データベースも Docker コンテナで動かし、Django が動いている
コンテナと Link させることにする。秘匿すべき設定情報の扱い方についても書く。

まず、
[Django Tutorial](https://github.com/fortune/django-tutorial#%E3%83%97%E3%83%AD%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88%E3%82%92%E4%BD%9C%E6%88%90%E3%81%99%E3%82%8B)
にならってプロジェクトを作成する。


## Visual Studio Code の設定

エディタとして VSCODE を使っているなら、エディタ内で使う Python を仮想環境内の Python にする。そうすると
プロジェクトトップのディレクトリの `.vscode/settings.json` のワークスペースの設定にそれが反映される。

ワークスペース内で、Django 対応の Lint ができるようにするために、

```shell
(myvenv) $ pip install pylint-django
```

としてプラグインをインストールしてから、`.vscode/settings.json` のワークスペース設定で

```json
{
    "python.pythonPath": "myvenv/bin/python",
    "python.linting.pylintArgs": [
        "--load-plugins=pylint_django"
    ]
}
```

のように `pylintArgs` を使うように指示する。


## settings の個別化と秘匿化

プロジェクト作成直後は、ベースのディレクトリにある `project` ディレクトリは次のような構造になっている。

```shell
(myvenv) $ tree project
project/
├── __init__.py
├── settings.py
├── urls.py
└── wsgi.py
```

これを次のように変更する。

```shell
(myvenv) $ tree project
project/
├── __init__.py
├── settings
│   ├── __init__.py
│   ├── base.py
│   └── fortune
│       ├── __init__.py
│       ├── secrets.json
│       └── settings.py
├── urls.py
└── wsgi.py
```

共通の設定を `base.py` に残し、本番環境やステージング環境、または各開発者ごとの環境は、`settings` ディレクトリ下に
環境ごとのディレクトリをつくって、そこに記述する。ここでは、`fortune` ユーザ用の環境として、`fortune` ディレクトリを
作った。データベースへの接続パスワードや、認証トークンなど、秘密にすべき情報は `secrets.json` に定義してそこから読み出すようにする。
本番環境やステージング環境用の `secrets.json` はバージョン管理システムに登録すべきではないので、`.gitignore` にそれらは
無視するように記述しておく。
にする。


## Django の起動

settings を個別下したので、起動方法が異なる。runserver なら、

```shell
(myvenv) $ python manage.py runserver --settings=project.settings.fortune.settings
```

とする。もしくは、

```shell
(myvenv) $ DJANGO_SETTINGS_MODULE=project.settings.fortune.settings python manage.py runserver
```

のようにする。



## Docker で PostgreSQL を使う

各開発者個人の環境であっても本番環境と同じデータベースを使うべきでなので、Django 付属の sqlite で済ませるのは避けた方がいい。
ここでは PostgreSQL を使うが、その場合でもわざわざ PostgreSQL をインストールして環境構築まではしたくない。そこで
Docker を使う。

[PostgreSQL の Docker Official リポジトリ](https://hub.docker.com/_/postgres/)

イメージを Pull する。

```shell
$ docker pull postgres:10.5-alpine
```

次のように実行する。

```shell
$ docker run --name some-postgres \     # 実行時のコンテナ名
             -e POSTGRES_PASSWORD=my_password \     # 使用するパスワードを環境変数で渡す
             -e POSTGRES_DB=my_db \     # 使用するデータベース名
             -p 5432:5432 \     # ホストとコンテナの 5432 ポートをつなぐ
             -d \       # Detached モード、つまりバックグラウンドでコンテナを実行
             postgres:10.5-alpine
```

ユーザ名は指定してないので、デフォルトの `postgres` が使われる。コンテナ同士で Link するだけなら -p オプションで
ホストとコンテナのポートをつなげる必要はないが、こうしたのは、後でコンテナを使わずに runserver したときのためだ。
    
こうすると、

```shell
$ docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS               NAMES
842c3a63089b        postgres:10.5-alpine   "docker-entrypoint.s…"   16 minutes ago      Up 16 minutes       5432/tcp            some-postgres
```

のようになるのだが、Docker の link を使って、ここに接続できる。

```shell
$ docker run -it --rm \
             --link some-postgres:postgres \    # some-postgres というコンテナに Link し、エイリアスとして postgres を指定する。
             ubuntu env     # Ubuntu をコンテナで起動し、env コマンドを実行して、環境変数を出力させる。
POSTGRES_PORT=tcp://172.17.0.2:5432
POSTGRES_PORT_5432_TCP=tcp://172.17.0.2:5432
POSTGRES_PORT_5432_TCP_ADDR=172.17.0.2
POSTGRES_PORT_5432_TCP_PORT=5432
POSTGRES_PORT_5432_TCP_PROTO=tcp
POSTGRES_NAME=/dazzling_noyce/postgres
POSTGRES_ENV_POSTGRES_PASSWORD=my_password
POSTGRES_ENV_LANG=en_US.utf8
POSTGRES_ENV_PG_MAJOR=10
POSTGRES_ENV_PG_VERSION=10.5
POSTGRES_ENV_PG_SHA256=6c8e616c91a45142b85c0aeb1f29ebba4a361309e86469e0fb4617b6a73c4011
POSTGRES_ENV_PGDATA=/var/lib/postgresql/data
```

このように、指定した `postgres` というエイリアスをプリフィックスにした環境変数がコンテナに渡されている。psql コマンドでつなぐには、

```shell
$ docker run -it --rm \
             --link some-postgres:postgres \
             postgres:10.5-alpine \
             psql -h postgres   # DB ホスト名
             -U postgres    # ユーザ名
```

のようにする。psql コマンドの -h オプションで指定するホスト名は、docker の --link オプションで指定したエイリアス名である。
psql コマンドの -U オプションでデフォルトユーザの postgres を指定している。パスワードを聞かれるので、PostgreSQL をコンテナで実行したときに
`POSTGRES_PASSWORD` 環境変数で指定したパスワードを入力する。


## Django アプリケーションから Docker コンテナ上の PostgreSQL へ接続する

まず、PostgreSQL に接続するためのライブラリをインストールする。

```shell
(myvenv) $ pip install psycopg2
```

先にコンテナで起動しておいた PostgreSQL へと接続するように settings を記述する。

`project/settings/fortune/settings.py` 内のデータベース部分の設定は、

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql_psycopg2',
        'NAME': get_secret(secrets, 'DB_NAME'),
        'USER': get_secret(secrets, 'DB_USER'),
        'PASSWORD': get_secret(secrets, 'DB_PASSWORD'),
        'HOST': get_secret(secrets, 'DB_HOST'),
        'PORT': '5432',
    }
}
```

とし、`project/settings/fortune/secrets.json` は

```json
{
    "": "CSRF 対策に使うシークレットキー",
    "SECRET_KEY": "hts+7ik2^(b&ldan!$)beae7&6zs1lxr8!9tnd%@u6+gmd_4zf",

    "": "DB への秘密にすべき接続情報",
    "DB_NAME": "my_db",
    "DB_USER": "postgres",
    "DB_PASSWORD": "my_password",
    "DB_HOST": "postgres"
}
```

のようにする。`DB_NAME`, `DB_PASSWORD` は PostgreSQL をコンテナで実行したときに指定したデータベース名、パスワードを使っているし、
`DB_USER` はデフォルトのユーザ名を指定している。`DB_HOST` として `postgres` を指定しているが、コンテナ同士の Link ではなく
ホスト上で直接 Django を起動して PostgreSQL に接続するので、/etc/hosts ファイルに `postgres` ホストが localhost へ向くように
設定しなければならない（Django をコンテナ上で動かすならこの設定は必要ない）。

ここまでくれば、コンテナ上で実行している PostgreSQL に対してマイグレーションを実行でき、管理者ユーザをつくり、runserver できる。

```shell
(myvenv) $ python manage.py migrate --settings=project.settings.fortune.settings
(myvenv) $ python manage.py createsuperuser --settings=project.settings.fortune.settings
(myvenv) $ python manage.py runserver --settings=project.settings.fortune.settings
```


## Django アプリの Docker コンテナ化

開発者個人のマシンで動かすだけなら Django をコンテナ上で実行する必要はないだろうが、ステージングや本番環境で実行する場合、
コンテナ化した方が都合がいい。

ここでは、Django 付属の runserver でも動かせるし、`uwsgi` を実行して HTTPS 接続もできるように Django をコンテナ化する。

まず、`uwsgi` をインストールし、requirements.txt を作成する。

```shell
(myvenv) $ pip install uwsgi
(myvenv) $ pip freeze >requirements.txt
```

また、uwsgi で動かす場合、`django.contrib.staticfiles` アプリケーションは使えないので、static ファイルを集約しておかねば
ならない。

`base.py` に

```python
STATIC_ROOT = os.path.join(BASE_DIR, 'static')
```

としておいて、

```shell
(myvenv) $ python manage.py collectstatic --settings=project.settings.fortune.settings
```

を実行すれば、ベースディレクトリの `static/` ディレクトリ下に static ファイルが集約される。

Docker まわりの設定をするためにベースディレクトリに `dockerable` ディレクトリを作成し、その下に環境ごとに
ディレクトリを作成する。ここでは次のような構成にした。

```shell
$ tree dockerable
dockerable
└── fortune
    ├── Dockerfile
    ├── cmd.sh
    └── ssl
        ├── server.crt
        ├── server.csr
        └── server.key
```

`Dockerfile` に Django アプリケーション用の Docker イメージを作成する手順を記述し、cmd.sh はサービス実行のためのスクリプトであり、
ssl/ ディレクトリには HTTPS 接続のための証明書ファイルを置く。

HTTP 接続用に自己署名の証明書をつくっておこう。

```shell
$ openssl genrsa 2024 >dockerable/fortune/ssl/server.key
$ openssl req -new -key dockerable/fortune/ssl/server.key >dockerable/fortune/ssl/server.csr
$ openssl x509 -req -days 3650 -signkey dockerable/fortune/ssl/server.key  <dockerable/fortune/ssl/server.csr >dockerable/fortune/ssl/server.crt
```

FQDN は `fortune.django-dockerable-sample.com` としよう。

では、Docker のイメージを作成する。イメージ名は、`django-dockerable-sample:1.0` とする。ビルドコンテキストは、Django のベースディレクトリだ。
次のコマンドを実行する。

```shell
$ docker build -t django-dockerable-sample:1.0 -f dockerable/fortune/Dockerfile .
```

`dockerable/fortune/Dockerfile` とビルドコンテクストにおいた `.dockerignore` により、

- コンテナの /app/ に Django アプリをコピーするが、
- dockerable/ 以下と project/settings/fortune は除くようにし、
- dockerable/fortune/cmd.sh を /cmd.sh へコピーする。

ようにしている。これにより、秘密にすべき設定情報や ssl 情報等がイメージに入らないようにしている。個人の開発環境なら問題はないだろうが、
本番環境などではこれが重要になる。

作成したイメージを使って Django アプリケーションをコンテナ上で実行するには次のようにする。

まず、PostgreSQL をコンテナ上で実行しておく必要がある。方法は前述のとおり。

コンテナ上で manage.py runserver を実行するなら、ベースディレクトリ上で

 ```shell
$ docker run --link some-postgres:postgres \
             -d \
             -p 80:8000 \
             -v $PWD:/app:ro \
             -e DJANGO_SETTINGS_MODULE=project.settings.fortune.settings \
             -e ENV=DEV \
             django-dockerable-sample:1.0
```

とする。ホストのポート 80 をコンテナのポート 8000 へつなげるようにしているので、ブラウザから http://localhost/ でアクセスできる。
また、コンテナの /app/ をホストの Django のベースディレクトリにマウントしているので、実行中にソースを変更すれば、web サーバが再起動される。

uwsgi を実行して、https 接続できるようにコンテナを起動するなら次のようにする。

```shell
$ docker run --link some-postgres:postgres \
             -d \
             -p 443:443 \
             -v $PWD/project/settings/fortune:/app/project/settings/fortune:ro \
             -v $PWD/dockerable/fortune/ssl:/ssl:ro \
             -e DJANGO_SETTINGS_MODULE=project.settings.fortune.settings \
             django-dockerable-sample:1.0
```

Django の settings と ssl 証明書がコンテナ側から利用できるように -v オプションでマウントしている。SSL 証明書を作成したとき、
FQDN として `fortune.django-dockerable-sample.com` を指定したので、
https://fortune.django-dockerable-sample.com/ でアクセスする。/etc/hosts にこのドメイン名が localhost を指すように記述しておく。

    
## docker-compose の利用

docker build するときや、docker run 時にコンテナ同士を適切に Link させたりするように、その都度、正しくオプション等を指定して
実行するのは大変だし、そのために独自のソリューションとしてシェルスクリプトを書くのも面倒なので、そういうときは
docker-compose を利用する。

```shell
$ tree dockerable
dockerable
└── fortune
    ├── Dockerfile
    ├── cmd.sh
    ├── docker-compose-dev.yml
    ├── docker-compose.yml
    └── ssl
        ├── server.crt
        ├── server.csr
        └── server.key
```

のように `docker-compose.yml` と `docker-compose-dev.yml` を作成した。前者は uwsgi 用、後者は manage.py runserver 用にコンテナを実行するための定義。

```shell
$ docker-compose up -d
```

とすれば、デフォルトの docker-compose.yml が使われ、

```shell
$ docker-compose -f docker-compose-dev.yml up -d
```

のようにファイルを指定することもできる。

双方とも django-dockerable-sample:1.0 イメージが存在しなければ build し、その後 run する。



## ステージング、本番環境用に Nginx を利用する


