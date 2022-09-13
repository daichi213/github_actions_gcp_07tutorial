# README

## APP 実行手順

### Infrastructure

1. 以下、リソースへの権限を持つ IAM ユーザーを作成する

2. Terraform から AWS 上へアクセスするための IAM ユーザーの設定を行う

- 設定パターン１（コマンド実行時に毎回入力しなくてもよく便利）
  terraform.tfvars へ以下の変数へ取得したアクセスキーとシークレットキーを設定する。
  ※ただし、このファイルは.gitignore にて追跡除外設定を行っていないため絶対に public repository へ push しないようにする

```tfvars
aws_access_key = "AKIA5KZDAAKDDPSB7UGJ"
aws_secret_key = "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"
```

- 設定パターン２
  特に設定を行わないパターンこの場合、`terraform apply`などの実行時にアクセスキーとシークレットキーが毎回入力する必要がある。しかし、クリティカルな情報をファイルに保持しないためうっかり事故を起こすことは避けられる。

3. AWS 上に開発用インスタンスを作成する

```bash
# infraディレクトリへ移動する
$ cd ./infra
# terraformの実行ファイルを生成する
$ terraform init
# 構成ファイルに問題ないか確認する
$ terraform plan
# Resourceを作成する
$ terraform apply
# この時点でインスタンスのPublicIPが出力されないため、再度applyを実行してインスタンスのIPを取得する
$ terraform apply
```

ここまでの手順で、AWS 上にリグレッション用のインスタンスを立ち上げることができる。

### サーバーの構成

#### 初回立ち上げ

vagrant 内に ansible を build してそこからサーバーの自動構成を実行する。

```bash
$ cd ../server_conf/vagrant
$ vagrant up ansible
$ vagrant ssh ansible
vagrant@ubuntu2204:~$ sudo su
root@ubuntu2204$ cd /etc/ansible/ansible
root@ubuntu2204$ ansible-playbook -i development site.yml
# この時点でserverコンテナーが立ち上がっていないためRailsがLISTENしているポートへアクセスできない。
# 原因はMySQLが立ち上がっていない状態でserverコンテナーを立ち上げようとして途中で処理が失敗していることによるエラーとなっている。そのため、MySQLコンテナーが立ち上がってから再度以下コマンドを実行し、ansibleからコンテナーの立ち上げを行う。
root@ubuntu2204$ ansible-playbook -i development site.yml
```

#### github actions→serverへの接続設定

github actionsから今回環境となっているEC2インスタンスに接続するためのssh関連の設定についてここに記載する。EC2インスタンスへの接続に使用する鍵はレポジトリへ直接アップできないため、github actionsの環境変数へexportしてくれる機能を利用する。
※今回使用した[Actionについて](https://qiita.com/shimataro999/items/b05a251c93fe6843cc16)

まずは、サーバーのホスト公開鍵を以下コマンドから取得する。
[keyscanで取得した情報は`ホスト名  キー種別  ホスト公開鍵`として取得される。](https://ttssh2.osdn.jp/manual/4/ja/setup/knownfiles.html)knwon_hostsもこれと同様の構成で登録を行えばよい。

```bash
$ ssh-keyscan <terraform.tfstateに出力されているインスタンスのPublic IP>
# 54.95.86.106:22 SSH-2.0-OpenSSH_8.9p1 Ubuntu-3
54.95.86.106 ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCop+YnjfRf58t0lZhyTa5iLlr9F5JV/i8dP9UE4vnem4hcMY5Xc1mvLnp8RmHmlJJLKoItpVtRR8w6SXfl6a6OR5TUygB+WYqrXGw9eQaI8rRXGaepbIAUsH9ewGFcPLb4NpdRNmi0Ilasek7opCQ2IwM8yEjNBAi/Svt9PTaMbXzkbbMrdNp5C1Zj7cRTI7Ug2z0hmJ/rad/JbOVdkEx8HkZHeQaYrFfk0+KhmqIHQNrAMMGcxyxUF/e+Euhn2hWa6nVHm/mTea/FjGIKZPAhwcD+dDL9dk0sa1SOzc+Bm8Yt+sPuGw5RB64++bT7eYTwS0ZWnsLPAKKRJ3GBLpWUUarIxTYw2KRS09tHnBjjbEOR2X9unB4SnkMIQY4wHkb/hdVgOZtFLFzoRUqKtoWNmCjUdai+1kTOQKeGzHWJDh9+2FgENMN5Zmf/1uv9LLPCidIMAPvg5cz5SH3gt2K2oolGitdjIM0FZHSSuWQl07EUzQy5DoAcn9Vgp0fZbBU=
...
```
今回、使用している鍵はRSA方式のものを使用しているため、keyscanして取得した`ssh-rsa`のものをコピーしてgit側で設定する。

#### gitの鍵登録方法

1. github actionsでの環境変数の設定は「Settings > Secrets > Actions」の順にリンクを踏んで「Actions secrets
」のタイトルの設定ページを開く。
2. 「New repository secret」のボタンを押す。
3. 「Actions secrets / New secret」のページが開くので、それぞれ登録を行う。
  - SSH_KEY（EC2インスタンスへssh接続するための秘密鍵）
    - Name : SSH_KEY
    - Value : <github_actions_gcp_07tutorial/infra/keys/id_rsaの内容をそのままコピーして登録>
  - KNOWN_HOSTS（開発環境のホスト公開鍵）
    - Name : KNOWN_HOSTS
    - Value : <以下内容>

>~~54.95.86.106~~ development ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCop+YnjfRf58t0lZhyTa5iLlr9F5JV/i8dP9UE4vnem4hcMY5Xc1mvLnp8RmHmlJJLKoItpVtRR8w6SXfl6a6OR5TUygB+WYqrXGw9eQaI8rRXGaepbIAUsH9ewGFcPLb4NpdRNmi0Ilasek7opCQ2IwM8yEjNBAi/Svt9PTaMbXzkbbMrdNp5C1Zj7cRTI7Ug2z0hmJ/rad/JbOVdkEx8HkZHeQaYrFfk0+KhmqIHQNrAMMGcxyxUF/e+Euhn2hWa6nVHm/mTea/FjGIKZPAhwcD+dDL9dk0sa1SOzc+Bm8Yt+sPuGw5RB64++bT7eYTwS0ZWnsLPAKKRJ3GBLpWUUarIxTYw2KRS09tHnBjjbEOR2X9unB4SnkMIQY4wHkb/hdVgOZtFLFzoRUqKtoWNmCjUdai+1kTOQKeGzHWJDh9+2FgENMN5Zmf/1uv9LLPCidIMAPvg5cz5SH3gt2K2oolGitdjIM0FZHSSuWQl07EUzQy5DoAcn9Vgp0fZbBU=

※今回、actionsのVM内でホスト名はIPアドレスではなく`development`のホスト名を使用しているため、以下のようにホスト名を修正して、登録する。名前解決は`/etc/hosts`にて実施される。

### SampleApp

今回、CI/CD パイプラインにてデプロイするアプリは Docker を使用して Rails にて作成してます。まずは、docker から build して簡単にアプリの編集をしていきましょう！

```bash
# プロジェクトのルートディレクトリへ移動する
$ cd ../
# compose.ymlが存在していればOK
$ ls
# Buildする
$ docker-compose build
# コンテナを立ち上げる
$ docker-compose up
```

- 以下アドレスをブラウザから開き、アプリの起動に問題がないか確認する
  http://localhost:3000

ここまでで、コンテナによる開発環境を立ち上げることができる。
ここで、別コマンドを開いて、コンテナへ接続する。

```bash
$ docker-compose exec app bash
```

## apt-repository について

[Docker レポジトリ](https://download.docker.com/linux/ubuntu/dists/jammy/stable/binary-amd64/)
apt の標準レポジトリに含まれていないライブラリは適宜レポジトリを追加する必要があるが、その際のレポジトリ追加方法をメモする。
そもそも apt のレポジトリを追加する際は`/etc/apt/sources.list.d/`配下にレポジトリ情報が保管される。

```bash
root@ubuntu2204:/etc/ansible/ansible# cat /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-jammy.list
deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable
# deb-src [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable
```

上記で設定したレポジトリからパッケージ管理ライブラリである apt が以下のようなパッケージ情報が格納されているファイルを読み込む。`apt update`の場合はそれらの最新ファイルを読み込むことで新しい依存関係を読み込むことを目的とする。

```
...
Package: docker-ce-cli
Architecture: arm64
Version: 5:20.10.9~3-0~debian-buster
Priority: optional
Section: admin
Source: docker-ce
Maintainer: Docker <support@docker.com>
Installed-Size: 143685
Depends: libc6 (>= 2.17)
Conflicts: docker (<< 1.5~), docker-engine, docker-engine-cs, docker.io, lxc-docker, lxc-docker-virtual-package
Breaks: docker-ce (<< 5:0)
Replaces: docker-ce (<< 5:0)
Filename: dists/buster/pool/stable/arm64/docker-ce-cli_20.10.9~3-0~debian-buster_arm64.deb
Size: 34713030
MD5sum: d3706730a428867d5a0499470b22c5ee
SHA1: f7445b0ba72d25c47ab7d5ecbb764fe7ff622e90
SHA256: ad3ad77dc329927902bfc6340b4b54578a684a822a5efd7d8e3013cab0b5b41b
SHA512: c7043b6b95ebd6324e7696ee9d1fd67b84cadaf9cd4c12631fd1167879203ca4aad874eda5094e634140f83aad4755b6f7e04a77873708eed0eaafe861743976
Homepage: https://www.docker.com
Description: Docker CLI: the open-source application container engine
 Docker is a product for you to build, ship and run any application as a
 lightweight container
 .
 Docker containers are both hardware-agnostic and platform-agnostic. This means
 they can run anywhere, from your laptop to the largest cloud compute instance and
 everything in between - and they don't require you to use a particular
 language, framework or packaging system. That makes them great building blocks
 for deploying and scaling web apps, databases, and backend services without
 depending on a particular stack or provider.
 ...
```

#### add-apt-repository

add-apt-repository コマンドの使用例を以下に記載する。このコマンドを使用すれば再帰的にパッケージ情報を読み込むことができる。

```bash
$ add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
# 上記コマンドは以下と等価（lsb_releaseはそれぞれの環境毎に異なる）
$ add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable"
```

上記のコマンドではこの[レポジトリ](https://download.docker.com/linux/ubuntu/dists/jammy/stable/)以下に存在しているパッケージ関連のファイルを再帰的にすべて読み込む。

手動で add-apt-repository により apt レポジトリを追加した際の挙動

```bash
root@ubuntu2204:/etc/ansible/ansible$ add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
Repository: 'deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable'
Description:
Archive for codename: jammy components: stable
More info: https://download.docker.com/linux/ubuntu
Adding repository.
Press [ENTER] to continue or Ctrl-c to cancel.
Adding deb entry to /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-jammy.list
Adding disabled deb-src entry to /etc/apt/sources.list.d/archive_uri-https_download_docker_com_linux_ubuntu-jammy.list
Get:1 https://download.docker.com/linux/ubuntu jammy InRelease [48.9 kB]
Get:2 https://download.docker.com/linux/ubuntu jammy/stable amd64 Packages [6,121 B]
Hit:3 https://mirrors.edge.kernel.org/ubuntu jammy InRelease
Get:4 https://mirrors.edge.kernel.org/ubuntu jammy-updates InRelease [114 kB]
Get:5 https://mirrors.edge.kernel.org/ubuntu jammy-backports InRelease [99.8 kB]
Get:6 https://mirrors.edge.kernel.org/ubuntu jammy-security InRelease [110 kB]
Get:7 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main amd64 Packages [377 kB]
Get:8 https://mirrors.edge.kernel.org/ubuntu jammy-updates/main Translation-en [94.3 kB]
Get:9 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe amd64 Packages [171 kB]
Get:10 https://mirrors.edge.kernel.org/ubuntu jammy-updates/universe amd64 c-n-f Metadata [4,128 B]
Get:11 https://mirrors.edge.kernel.org/ubuntu jammy-security/main amd64 Packages [225 kB]
Get:12 https://mirrors.edge.kernel.org/ubuntu jammy-security/main Translation-en [54.6 kB]
Get:13 https://mirrors.edge.kernel.org/ubuntu jammy-security/main amd64 c-n-f Metadata [3,564 B]
Get:14 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted amd64 Packages [203 kB]
Get:15 https://mirrors.edge.kernel.org/ubuntu jammy-security/restricted Translation-en [30.4 kB]
Get:16 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe amd64 Packages [93.5 kB]
Get:17 https://mirrors.edge.kernel.org/ubuntu jammy-security/universe amd64 c-n-f Metadata [2,068 B]
Fetched 1,638 kB in 3s (544 kB/s)
Reading package lists... Done
W: https://download.docker.com/linux/ubuntu/dists/jammy/InRelease: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg), see the DEPRECATION section in apt-key(8) for details.
```

## Github action_dispatch

### Workflow 関連の設計方法について

[GitHub Actions における Step/Job/Workflow 設計論](https://zenn.dev/hsaki/articles/github-actions-component)

### Debugging

[SSH デバッグ](https://zenn.dev/luma/articles/21e66e11cc4aa8d0f9ae)を行い、実際に CI とそのテストが行われている環境に接続して job の run に使用するコマンドの作成を行なった。

## Rails

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

- Ruby version

- System dependencies

- Configuration

- Database creation

- Database initialization

- How to run the test suite

- Services (job queues, cache servers, search engines, etc.)

- Deployment instructions

- ...
