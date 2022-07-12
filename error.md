# The encounting errors with Github actions

## APPコンテナからDBコンテナへの接続エラー

RailsをbuildしているappコンテナからMySQLをbuildしているdbコンテナへ接続を行い、テスト環境の作成コマンドを作成していたが以下のようなエラーに遭遇してしまった。

```bash
$ docker-compose exec -T app rails db:create
Can't connect to MySQL server on 'db' (115)
Couldn't create 'sample_app_development' database. Please check your configuration.
rails aborted!
ActiveRecord::ConnectionNotEstablished: Can't connect to MySQL server on 'db' (115)
```

### 対応

[Dockerで構築したRailsアプリをGitHub Actionsで高速にCIする為のプラクティス（Rails 6 API編）](https://qiita.com/jpshadowapps/items/f32314ba827510cfe504)のセットアップでコンテナがLISTENを開始するまで処理を待機させることができるMWが紹介されていたので、参考にさせていただいた。

### ハマったポイント
そもそもコンテナが起動していればLISTENも完了していると思い込んでいたため、原因の絞り込みまで行えていなかった。また、[SSHデバッグ](https://zenn.dev/luma/articles/21e66e11cc4aa8d0f9ae)を使用して原因の調査は行っていたが、原因の絞り込みすらうまくいっていなかった。
