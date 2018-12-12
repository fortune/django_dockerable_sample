# Dockerable Django Project

Django アプリケーションを Docker コンテナ上で動かすサンプル。データベースも Docker コンテナで動かし、Django が動いている
コンテナと Link させることにする。

本番環境、ステージング、開発者ごとの環境のような環境ごとの設定は個別化し、必要な部分は秘匿化する一方で、共通のコンテナイメージを
作成することにする。したがって、コンテナ実行時に環境を指定する。

まず、
[Django Tutorial](https://github.com/fortune/django-tutorial#%E3%83%97%E3%83%AD%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88%E3%82%92%E4%BD%9C%E6%88%90%E3%81%99%E3%82%8B)
にならって空のプロジェクトを作成する。


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
秘密情報が入った `secrets.json` はバージョン管理システムに登録すべきではないので、`.gitignore` にそれらは
無視するように記述しておく（`fortune` ユーザのはサンプルのため、例外として登録してある）。


## Django の起動

settings を個別下したので、起動方法が異なる。runserver なら、

```shell
(myvenv) $ python manage.py runserver --settings=project.settings.fortune.settings
```

とする。もしくは、

```shell
(myvenv) $ DJANGO_SETTINGS_MODULE=project.settings.fortune.settings python manage.py runserver
```

のようにする。ただし、`manage.py` を修正して、デフォルトの settings として `project.settings.base` を使用するようにしてあるので、
`base.py` に定義した設定だけで済む場合、たとえば、runserver でなく、shell や collectstatic の場合など、settings を指定しないでも起動できる。



## Docker で PostgreSQL を使う

各開発者個人の環境であっても本番環境と同じデータベースを使うべきでなので、Django 付属の sqlite で済ませるのは避けた方がいい。
ここでは PostgreSQL を使うが、その場合でもわざわざ PostgreSQL をインストールして環境構築まではしたくない。そこで
Docker を使う。

[PostgreSQL の Docker Official リポジトリ](https://hub.docker.com/_/postgres/)

イメージを Pull する。

```shell
$ docker pull postgres:10.5-alpine
```

次のように起動できる。ここでは何の設定もしないが、実際には、起動後、必要な設定をし、イメージを保存するのだろう。

```shell
$ docker run --name some-postgres \     # 実行時のコンテナ名
             -e POSTGRES_PASSWORD=my_password \     # 使用するパスワードを環境変数で渡す
             -e POSTGRES_DB=my_db \     # 使用するデータベース名
             -p 5432:5432 \     # ホストとコンテナの 5432 ポートをつなぐ
             -d \       # Detached モード、つまりバックグラウンドでコンテナを実行
             postgres:10.5-alpine
```

ユーザ名は指定してないので、デフォルトの `postgres` が使われる。コンテナ同士で Link するだけなら -p オプションで
ホストとコンテナのポートをつなげる必要はないが、こうしたのは、後でコンテナを使わずに Django を runserver するときのためだ。
    
こうすると、

```shell
$ docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS               NAMES
842c3a63089b        postgres:10.5-alpine   "docker-entrypoint.s…"   16 minutes ago      Up 16 minutes       5432/tcp            some-postgres
```

のようになる。このコンテナに Docker の link を使って、接続できる。

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

指定した `postgres` というエイリアスをプリフィックスにした環境変数がコンテナに渡されており、このコンテナから先の PostgreSQL の
コンテナに接続できる。psql コマンドでつなぐには、

```shell
$ docker run -it --rm \
             --link some-postgres:postgres \
             postgres:10.5-alpine \
             psql -h postgres \   # DB ホスト名
             -U postgres    # ユーザ名
```

のようにする。psql コマンドの -h オプションで指定するホスト名は、docker の --link オプションで指定したエイリアス名である。
psql コマンドの -U オプションでデフォルトユーザの postgres を指定している。パスワードを聞かれるので、PostgreSQL をコンテナで
実行したときに `POSTGRES_PASSWORD` 環境変数で指定したパスワードを入力する。


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

起動された Django アプリは Docker コンテナとして実行中の PostgreSQL へ接続している。



## Django アプリの Docker コンテナとしてビルドする

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

Docker イメージのビルド設定を格納するため、ベースディレクトリに `dockerable` ディレクトリを作成し、必要なファイルを作成する。


```shell
$ tree dockerable
dockerable/
├── Dockerfile
├── cmd.sh
└── docker-compose-build-only.yml

```

`Dockerfile` に Django アプリケーション用の Docker イメージを作成する手順を記述し、cmd.sh はサービス実行のためのスクリプトであり、
`docker-compose-build-only.yml` は、`docker-compose` ツールを使ってビルドするときのためのファイル。イメージをひとつだけ作成するので
こうしているが、もし、複数のイメージを作成するなら、イメージごとにディレクトリをつくり、その中に作成すべきだろう。

では、ビルドしよう。次のコマンドを実行する。

```shell
$ docker build -t django-dockerable-sample:1.0 -f dockerable/Dockerfile .
```

`dockerable/Dockerfile` と `.dockerignore` により、

- コンテナの /app/ に Django アプリをコピーするが、
- dockerable/ 以下と project/settings/ 下の base.py 以外はイメージに入らないようにし、
- dockerable/cmd.sh を コンテナ上の /cmd.sh へコピーする。

ようにしている。これにより、秘密にすべき情報や個別の環境がイメージに入らないようにしている。

ビルドするとき、いちいちタグ名を指定するのも面倒なので、docker-compose ツールを使う方がいい。ビルドだけに使うための
`docker-compose-build-only.yml` も作成したので、それを指定して実行する。

```shell
$ docker-compose -f dockerable/docker-compose-build-only.yml build
```

ここで作成したコンテナイメージを本番、ステージング、開発者個人の環境で共通して使用する。環境ごとの違いは実行時に指定する。


## Docker コンテナ化した Django アプリ実行用の環境を作成する

`project/settings/` 以下に環境ごとのディレクトリを作成し、そこで環境固有の Django 設定をするのだった。さらに
Docker コンテナを実行するときの環境もそこに作成する。そういうわけで、`project/settings/fortune/` 以下は次のようになる。

```shell
$ tree fortune
fortune/
├── __init__.py
├── docker-compose-dev.yml
├── docker-compose.yml
├── secrets.json
├── settings.py
└── ssl
    ├── server.crt
    ├── server.csr
    └── server.key
```

`docker-compose.yml` は、先程作成した Django コンテナイメージを docker-compose で実行するための yaml ファイル。
`docker-compose-dev.yml` も同様だが、開発モードで実行するときの設定を記述した yaml ファイル。ssl/ 以下には
HTTPS 接続用の SSL 証明書を格納しているが、これらは自己署名で次のように作成した。

```shell
$ openssl genrsa 2024 >project/settings/fortune/ssl/server.key
$ openssl req -new -key project/settings/fortune/ssl/server.key >project/settings/fortune/ssl/server.csr
$ openssl x509 -req -days 3650 -signkey project/settings/fortune/ssl/server.key  <project/settings/fortune/ssl/server.csr >project/settings/fortune/ssl/server.crt
```

FQDN は `fortune.django-dockerable-sample.com` としよう。



## Docker コンテナ化した Django アプリを開発モードで実行する

開発モード、つまり、コンテナ上で Django を runserver で実行するやり方。

まず、PostgreSQL コンテナを起動しておく。

```shell
$ docker run --name some-postgres \     # 実行時のコンテナ名
             -e POSTGRES_PASSWORD=my_password \     # 使用するパスワードを環境変数で渡す
             -e POSTGRES_DB=my_db \     # 使用するデータベース名
             # -p 5432:5432 \     # ホストとコンテナの 5432 ポートをつなぐ
             -d \       # Detached モード、つまりバックグラウンドでコンテナを実行
             postgres:10.5-alpine
```

PostgreSQL へはコンテナ同士のリンクで接続するので、-p オプションでホスト上のポートとつなげる必要はない。

次に、Docker イメージとしてビルドしておいた Django アプリを起動する。

```shell
$ docker run --link some-postgres:postgres \
             -d \
             -p 80:8000 \
             -v $PWD:/app:ro \
             -e DJANGO_SETTINGS_MODULE=project.settings.fortune.settings \
             -e ENV=DEV \
             django-dockerable-sample:1.0
```

ホストのポート 80 をコンテナのポート 8000 へつなげるようにしているので、ブラウザから http://localhost/ でアクセスできる。
また、コンテナの /app/ をホストの Django のベースディレクトリにマウントしているので、実行中にソースを変更すれば、web サーバが再起動される。

これらの引数やオプションを入力するのは面倒なので、docker-compose を使うべき。そのための yaml ファイルは用意してあるので
次のようにする。


```shell
$ docker-compose -f project/settings/fortune/docker-compose-dev.yml up -d
```





## Docker コンテナ化した Django アプリを本番モードで実行する

uwsgi を実行して、https 接続できるようにコンテナを起動するなら次のようにする。

```shell
$ docker run --link some-postgres:postgres \
             -d \
             -p 443:443 \
             -v $PWD/project/settings/fortune:/app/project/settings/fortune:ro \
             -v $PWD/project/settings/fortune/ssl:/ssl:ro \
             -e DJANGO_SETTINGS_MODULE=project.settings.fortune.settings \
             django-dockerable-sample:1.0
```

Django の settings と ssl 証明書がコンテナ側から利用できるように -v オプションでマウントしている。SSL 証明書を作成したとき、
FQDN として `fortune.django-dockerable-sample.com` を指定したので、
https://fortune.django-dockerable-sample.com/ でアクセスする。/etc/hosts にこのドメイン名が localhost を指すように記述しておく。

これも docker-compose を使うべき。次のようにする。

```shell
$ docker-compose -f project/settings/fortune/docker-compose.yml up -d
```


## まとめ

Django アプリケーションを Docker コンテナ化して実行するやり方をまとめた。基本的な方針は、

- コンテナイメージはすべての環境で共通とし、ビルドに必要な設定のみ、*dockerable/* ディレクトリに格納する。
- コンテナ実行方法も含めた、環境ごとの違いは、*project/settings/環境ごとのディレクトリ/* に定義し、これはコンテナイメージには含めない。

とする。docker-compose.yml ファイルには build コマンドのための指定と実行方法の指定もすべて含めてしまうのが普通のようだが、
そうはせずに分割しておく。こうすることで、イメージを共通化しつつ、環境ごとに実行方法を柔軟に変更できる。

ホストにデプロイするときは、Docker コンテナイメージをホストに配置し、*環境ごとのディレクトリ/* 以下もホストに
もっていく。たとえば、環境ごとのディレクトリが *staging/* ディレクトリならば、それを固めてホスト上にもっていって、

```shell
$ docker-compose -f staging/docker-compose.yml up -d
```

のようにすればよい。


## 課題

実際の運用では、Nginx をリバースプロキシとして使うだろう。また、SSL 証明書の自動更新等の設定も必要。

