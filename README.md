# README

## APP実行手順

### Infrastructure

1. 以下、リソースへの権限を持つIAMユーザーを作成する

2. TerraformからAWS上へアクセスするためのIAMユーザーの設定を行う
- 設定パターン１（コマンド実行時に毎回入力しなくてもよく便利）
terraform.tfvarsへ以下の変数へ取得したアクセスキーとシークレットキーを設定する。
※ただし、このファイルは.gitignoreにて追跡除外設定を行っていないため絶対にpublic repositoryへpushしないようにする
```tfvars
aws_access_key = "AKIA5KZDAAKDDPSB7UGJ"
aws_secret_key = "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"
```

- 設定パターン２
特に設定を行わないパターンこの場合、`terraform apply`などの実行時にアクセスキーとシークレットキーが毎回入力する必要がある。しかし、クリティカルな情報をファイルに保持しないためうっかり事故を起こすことは避けられる。

3. AWS上に開発用インスタンスを作成する

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

ここまでの手順で、AWS上にリグレッション用のインスタンスを立ち上げることができる。

### SampleApp

今回、CI/CDパイプラインにてデプロイするアプリはDockerを使用してRailsにて作成してます。まずは、dockerからbuildして簡単にアプリの編集をしていきましょう！

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

## Github action_dispatch

### Workflow関連の設計方法について

[GitHub ActionsにおけるStep/Job/Workflow設計論](https://zenn.dev/hsaki/articles/github-actions-component)

### Debugging

[SSHデバッグ](https://zenn.dev/luma/articles/21e66e11cc4aa8d0f9ae)を行い、実際にCIとそのテストが行われている環境に接続してjobのrunに使用するコマンドの作成を行なった。

## Rails

This README would normally document whatever steps are necessary to get the
application up and running.

Things you may want to cover:

* Ruby version

* System dependencies

* Configuration

* Database creation

* Database initialization

* How to run the test suite

* Services (job queues, cache servers, search engines, etc.)

* Deployment instructions

* ...
