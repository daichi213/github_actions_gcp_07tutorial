# The encounting errors with Github actions

## APP コンテナから DB コンテナへの接続エラー

Rails を build している app コンテナから MySQL を build している db コンテナへ接続を行い、テスト環境の作成コマンドを作成していたが以下のようなエラーに遭遇してしまった。

```bash
$ docker-compose exec -T app rails db:create
Can't connect to MySQL server on 'db' (115)
Couldn't create 'sample_app_development' database. Please check your configuration.
rails aborted!
ActiveRecord::ConnectionNotEstablished: Can't connect to MySQL server on 'db' (115)
```

### 対応

[Docker で構築した Rails アプリを GitHub Actions で高速に CI する為のプラクティス（Rails 6 API 編）](https://qiita.com/jpshadowapps/items/f32314ba827510cfe504)のセットアップでコンテナが LISTEN を開始するまで処理を待機させることができる MW が紹介されていたので、参考にさせていただいた。

### ハマったポイント

そもそもコンテナが起動していれば LISTEN も完了していると思い込んでいたため、原因の絞り込みまで行えていなかった。また、[SSH デバッグ](https://zenn.dev/luma/articles/21e66e11cc4aa8d0f9ae)を使用して原因の調査は行っていたが、原因の絞り込みすらうまくいっていなかった。

## Terraform

### Debugging

[以下のように環境変数を設定することで、terraform コマンド実行時にデバッグモードで起動することができる](https://qiita.com/kuwa_tw/items/15e80ecb9b23a11f537e)。windows の場合は、OS を再起動しなければ反映されないため、以下のコマンド実行後に OS の再起動を実施する必要がある。

```powershell
setx TF_LOG 1
setx TF_LOG_PATH './terraform.log'
```

## git

### 巨大なファイルを誤って push した際の対処

git では 100MB 以上のファイルはリモートレポジトリへ push できないが、今回誤って追跡対象から外す前にリモートレポジトリへ push してしまい、かなりハマってしまったためその対処方法をメモしておく。
この時点で、`git rm --cached`や.gitignore への記載などは行っていたが、現在のステージングに問題となっている terraform の exe ファイルが追跡から外れていなかったためエラーが解決しなかった。`git status`で確認してもファイルが見つからなかったため、原因把握までに時間が掛かってしまった。
具体的には[誤って 100MB 以上のファイルを push した際の対処](https://qiita.com/ffggss/items/b61e726bc8cbd3137956)を参考にして解決したが、この記事では`git reset --hard`を使用しているため、誤って削除してはならないファイルまで削除してしまう危険性があるため、hard オプションを soft オプションへ変更した方が安全。
具体的に、以下のようなエラーが発生していた。

```powershell
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push origin develop
Enumerating objects: 45, done.
Counting objects: 100% (45/45), done.
Delta compression using up to 12 threads
Compressing objects: 100% (20/20), done.
Writing objects: 100% (33/33), 56.34 MiB | 221.00 KiB/s, done.
remote: Resolving deltas: 100% (13/13), completed with 7 local objects.
remote: error: Trace: 10ddec2f1fdbfc8b6a4d559236b439734b7ea8364de1235eced42f5a8491c8e1
remote: error: See http://git.io/iEPt8g for more information.
remote: error: File infra/.terraform/providers/registry.terraform.io/hashicorp/aws/4.22.0/windows_amd64/terraform-provider-aws_v4.22.0_x5.exe is 267.22 MB; this exceeds GitHub's file size limit of 100.00 MB
 ! [remote rejected] develop -> develop (pre-receive hook declined)
```

### 対処

今回の根本的な原因はステージに巨大ファイルが残ってしまっていたことが原因だったため、以下の方法で巨大ファイルをステージから除外した。

- `git reset`によるステージの巻き戻し
  - 巻き戻しは`git log`コマンドを使用して巻き戻すステージの COMMIT ID を取得して`git reset --soft <HEADとしたいcommit id>`でリセットする
  - ステージが一つ前であれば`git reset --soft HEAD^`コマンドでも戻せる
- `git gc`により参照ログから巨大ファイルが残らないように削除する
- `git rm --cached`によるキャッシュファイルの削除
  - `git status`を実行するか vscode 上でステージされたファイルとなっていなければ OK
  - このコマンドは`git add .`により index へ追加したファイルを削除する。そのため、`git add`していなければ not found になる。
- .gitignore へ追跡除外対象ファイルの記載
  - log 拡張子を除外するために、`.log`で記載していたが他の記載も無効になってしまっていた。
  - ＊を含めて指定することでしっかりと除外できた。

#### 解決した際のコマンドログ

```powershell
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git reset HEAD ./infra/.terraform/providers/registry.terraform.io/hashicorp/aws/4.22.0/windows_amd64/terraform-provider-aws_v4.22.0_x5.exe
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push origin develop
Enumerating objects: 45, done.
Counting objects: 100% (45/45), done.
Compressing objects: 100% (20/20), done.
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git reset HEAD ./infra/.terraform/providers/
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git status
On branch develop

nothing to commit, working tree clean
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git gc
Enumerating objects: 378, done.
Writing objects: 100% (378/378), done.
Total 378 (delta 117), reused 376 (delta 116), pack-reused 0
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git reset HEAD ./infra/.terraform/providers/
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push origin develop
Enumerating objects: 45, done.
Counting objects: 100% (45/45), done.
Delta compression using up to 12 threads
PS C:\Users\besta\app\github_actions_gcp_07tutorial> s
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git reset
M       infra/instances.tf
M       infra/output.tf
M       infra/terraform.tfstate
M       infra/terraform.tfstate.backup
M       infra/terraform.tfvars
M       infra/variables.tf
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached .\infra\terraform.log
fatal: pathspec '.\infra\terraform.log' did not match any files
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached ./infra/terraform.log
fatal: pathspec './infra/terraform.log' did not match any files
PS C:\Users\besta\app\github_actions_gcp_07tutorial> ls


    ディレクトリ: C:\Users\besta\app\github_actions_gcp_07tutorial


----                 -------------         ------ ----
d-----        2022/07/13     10:00                .github
d-----        2022/07/16     14:33                sample_app
-a----        2022/07/13     10:07            722 docker-compose.yml
-a----        2022/07/16     14:08           1394 error.md
-a----        2022/07/16     14:08            841 README.md


PS C:\Users\besta\app\github_actions_gcp_07tutorial> git add .
warning: LF will be replaced by CRLF in infra/terraform.log.
The file will have its original line endings in your working directory
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached ./infra/terraform.log
rm 'infra/terraform.log'
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push origin develop
Enumerating objects: 32, done.
Counting objects: 100% (32/32), done.
Delta compression using up to 12 threads
Compressing objects: 100% (13/13), done.
Total 22 (delta 6), reused 14 (delta 1), pack-reused 0
remote: Resolving deltas: 100% (6/6), completed with 6 local objects.
remote: error: Trace: 970bd7098609c4e5da6e1f24478a78360e2a2f82c9fd21c61f9c7c223bb762e4
remote: error: See http://git.io/iEPt8g for more information.
remote: error: File infra/.terraform/providers/registry.terraform.io/hashicorp/aws/4.22.0/windows_amd64/terraform-provider-aws_v4.22.0_x5.exe is 267.22 MB; this exceeds GitHub's file size limit of 100.00 MB
remote: error: GH001: Large files detected. You may want to try Git Large File Storage - https://git-lfs.github.com.
To https://github.com/daichi213/github_actions_gcp_07tutorial.git
 ! [remote rejected] develop -> develop (pre-receive hook declined)
error: failed to push some refs to 'https://github.com/daichi213/github_actions_gcp_07tutorial.git'
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push -h
usage: git push [<options>] [<repository> [<refspec>...]]

    -v, --verbose         be more verbose
    -q, --quiet           be more quiet
    --repo <repository>   repository
    --all                 push all refs
    --mirror              mirror all refs
    -d, --delete          delete refs
    --tags                push tags (can't be used with --all or --mirror)
    -n, --dry-run         dry run
    --porcelain           machine-readable output
    -f, --force           force updates
    --force-with-lease[=<refname>:<expect>]
                          require old value of ref to be at this value
    --force-if-includes   require remote updates to be integrated locally
    --recurse-submodules (check|on-demand|no)
                          control recursive pushing of submodules
    --thin                use thin pack
    --receive-pack <receive-pack>
                          receive pack program
    --exec <receive-pack>
                          receive pack program
    -u, --set-upstream    set upstream for git pull/status
    --progress            force progress reporting
    --no-verify           bypass pre-push hook
    --follow-tags         push missing but relevant tags
    --signed[=(yes|no|if-asked)]
                          GPG sign the push
    --atomic              request atomic transaction on remote side
    -o, --push-option <server-specific>
Pushing to https://github.com/daichi213/github_actions_gcp_07tutorial.git
Enumerating objects: 32, done.
Counting objects: 100% (32/32), done.
Delta compression using up to 12 threads
Compressing objects: 100% (13/13), done.
POST git-receive-pack (chunked)
PS C:\Users\besta\app\github_actions_gcp_07tutorial> s
PS C:\Users\besta\app\github_actions_gcp_07tutorial>
PS C:\Users\besta\app\github_actions_gcp_07tutorial>
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git diff
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git status
On branch develop
Your branch is ahead of 'origin/develop' by 1 commit.
  (use "git push" to publish your local commits)

Changes to be committed:
  (use "git restore --staged <file>..." to unstage)
        new file:   .gitignore
        modified:   infra/output.tf
        modified:   infra/terraform.tfstate
        modified:   infra/terraform.tfstate.backup
        modified:   infra/terraform.tfvars
        modified:   infra/variables.tf

Untracked files:
  (use "git add <file>..." to include in what will be committed)
        infra/terraform.log

PS C:\Users\besta\app\github_actions_gcp_07tutorial> git log
Date:   Fri Jul 15 01:06:32 2022 +0900

    update the infra

commit 9cc1184ce7faa2257e76d0fe55080090bc0801dc (origin/develop)
Author: unknown <bestabokadon910@icloud.com>
Date:   Thu Jul 14 22:28:18 2022 +0900

    add the infra codes
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git reset --soft HEAD^
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git log
Author: unknown <bestabokadon910@icloud.com>


Author: 尾崎大地 <ozakidaichi@ozakidaichinoMacBook-Pro.local>

    add deploy job to workflow
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached -r .\infra\.terraform
rm 'infra/.terraform/providers/registry.terraform.io/hashicorp/aws/4.22.0/windows_amd64/terraform-provider-aws_v4.22.0_x5.exe'
rm 'infra/.terraform.lock.hcl'
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached -r .\infra\terraform.tfstate.backup
rm 'infra/terraform.tfstate.backup'
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push origin develop
Everything up-to-date
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git commit -m "complete infrastructure"
[develop 33b0737] complete infrastructure
 10 files changed, 174 insertions(+), 84 deletions(-)
 create mode 100644 .gitignore
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push origin develop
Counting objects: 100% (27/27), done.
Delta compression using up to 12 threads
Compressing objects: 100% (12/12), done.
Writing objects: 100% (15/15), 2.77 KiB | 2.77 MiB/s, done.
Total 15 (delta 7), reused 6 (delta 1), pack-reused 0
remote: Resolving deltas: 100% (7/7), completed with 7 local objects.
To https://github.com/daichi213/github_actions_gcp_07tutorial.git
   9cc1184..33b0737  develop -> develop
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached
fatal: No pathspec was given. Which files should I remove?
PS C:\Users\besta\app\github_actions_gcp_07tutorial> bash
Welcome to Ubuntu 20.04.3 LTS (GNU/Linux 5.10.16.3-microsoft-standard-WSL2 x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Sat Jul 16 15:29:44 JST 2022

  System load:  0.09               Processes:             13
  Usage of /:   1.0% of 250.98GB   Users logged in:       0
  Memory usage: 15%                IPv4 address for eth0: 172.30.191.227
  Swap usage:   0%

102 updates can be applied immediately.
50 of these updates are standard security updates.
To see these additional updates run: apt list --upgradable


The list of available updates is more than a week old.
To check for new updates run: sudo apt update


PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached .
fatal: not removing '.' recursively without -r
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git rm --cached -r .
rm '.github/workflows/deploy.yml'
rm '.github/workflows/develop.yml'
rm '.github/workflows/subflows/deploy.yml'
rm '.github/workflows/subflows/test.yml'
rm '.github/workflows/test.yml'
rm '.gitignore'
rm 'README.md'
rm 'docker-compose.yml'
rm 'error.md'
rm 'infra/iam-role.tf'
rm 'infra/iam_for_development.tf'
rm 'infra/instances.tf'
rm 'infra/keys/id_rsa'
rm 'infra/keys/id_rsa.pub'
rm 'infra/output.tf'
rm 'infra/policies/instance_policy.json'
rm 'infra/roles/instance_role.json'
rm 'infra/terraform.tf'
rm 'infra/terraform.tfstate'
rm 'infra/terraform.tfvars'
rm 'infra/variables.tf'
rm 'sample_app/.gitattributes'
rm 'sample_app/.gitignore'
rm 'sample_app/.rspec'
rm 'sample_app/.ruby-version'
rm 'sample_app/Dockerfile'
rm 'sample_app/Gemfile'
rm 'sample_app/Gemfile.lock'
rm 'sample_app/Rakefile'
rm 'sample_app/app/assets/config/manifest.js'
rm 'sample_app/app/assets/images/.keep'
rm 'sample_app/app/assets/stylesheets/application.css'
rm 'sample_app/app/channels/application_cable/channel.rb'
rm 'sample_app/app/channels/application_cable/connection.rb'
rm 'sample_app/app/controllers/application_controller.rb'
rm 'sample_app/app/controllers/concerns/.keep'
rm 'sample_app/app/controllers/hello_worlds_controller.rb'
rm 'sample_app/app/helpers/application_helper.rb'
rm 'sample_app/app/helpers/hello_worlds_helper.rb'
rm 'sample_app/app/javascript/application.js'
rm 'sample_app/app/javascript/controllers/application.js'
rm 'sample_app/app/javascript/controllers/hello_controller.js'
rm 'sample_app/app/javascript/controllers/index.js'
rm 'sample_app/app/jobs/application_job.rb'
rm 'sample_app/app/mailers/application_mailer.rb'
rm 'sample_app/app/models/application_record.rb'
rm 'sample_app/app/models/concerns/.keep'
rm 'sample_app/app/models/hello_world.rb'
rm 'sample_app/app/views/hello_worlds/index.html.erb'
rm 'sample_app/app/views/layouts/application.html.erb'
rm 'sample_app/app/views/layouts/mailer.html.erb'
rm 'sample_app/app/views/layouts/mailer.text.erb'
rm 'sample_app/bin/bundle'
rm 'sample_app/bin/importmap'
rm 'sample_app/bin/rails'
rm 'sample_app/bin/rake'
rm 'sample_app/bin/setup'
rm 'sample_app/config.ru'
rm 'sample_app/config/application.rb'
rm 'sample_app/config/boot.rb'
rm 'sample_app/config/cable.yml'
rm 'sample_app/config/credentials.yml.enc'
rm 'sample_app/config/database.yml'
rm 'sample_app/config/environment.rb'
rm 'sample_app/config/environments/development.rb'
rm 'sample_app/config/environments/production.rb'
rm 'sample_app/config/environments/test.rb'
rm 'sample_app/config/importmap.rb'
rm 'sample_app/config/initializers/assets.rb'
rm 'sample_app/config/initializers/content_security_policy.rb'
rm 'sample_app/config/initializers/filter_parameter_logging.rb'
rm 'sample_app/config/initializers/inflections.rb'
rm 'sample_app/config/initializers/permissions_policy.rb'
rm 'sample_app/config/locales/en.yml'
rm 'sample_app/config/puma.rb'
rm 'sample_app/config/routes.rb'
rm 'sample_app/config/storage.yml'
rm 'sample_app/db/migrate/20220710013233_create_hello_worlds.rb'
rm 'sample_app/db/schema.rb'
rm 'sample_app/db/seeds.rb'
rm 'sample_app/lib/assets/.keep'
rm 'sample_app/lib/tasks/.keep'
rm 'sample_app/log/.keep'
rm 'sample_app/public/404.html'
rm 'sample_app/public/422.html'
rm 'sample_app/public/500.html'
rm 'sample_app/public/apple-touch-icon-precomposed.png'
rm 'sample_app/public/apple-touch-icon.png'
rm 'sample_app/public/favicon.ico'
rm 'sample_app/public/robots.txt'
rm 'sample_app/spec/models/hello_world_spec.rb'
rm 'sample_app/spec/rails_helper.rb'
rm 'sample_app/spec/requests/hello_world_spec.rb'
rm 'sample_app/spec/spec_helper.rb'
rm 'sample_app/storage/.keep'
rm 'sample_app/test/application_system_test_case.rb'
rm 'sample_app/test/channels/application_cable/connection_test.rb'
rm 'sample_app/test/controllers/.keep'
rm 'sample_app/test/controllers/hello_worlds_controller_test.rb'
rm 'sample_app/test/fixtures/files/.keep'
rm 'sample_app/test/fixtures/hello_worlds.yml'
rm 'sample_app/test/helpers/.keep'
rm 'sample_app/test/mailers/.keep'
rm 'sample_app/test/models/.keep'
rm 'sample_app/test/models/hello_world_test.rb'
rm 'sample_app/test/test_helper.rb'
rm 'sample_app/tmp/.keep'
rm 'sample_app/tmp/pids/.keep'
rm 'sample_app/tmp/storage/.keep'
rm 'sample_app/vendor/.keep'
rm 'sample_app/vendor/javascript/.keep'
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git stash save
warning: LF will be replaced by CRLF in infra/keys/id_rsa.
The file will have its original line endings in your working directory
Saved working directory and index state WIP on develop: 33b0737 complete infrastructure
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git log
Date:   Sat Jul 16 15:28:43 2022 +0900


commit 9cc1184ce7faa2257e76d0fe55080090bc0801dc
Author: unknown <bestabokadon910@icloud.com>
Date:   Thu Jul 14 22:28:18 2022 +0900

    add the infra codes
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git add .
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git commit -m "update the gitignore file"
[develop ae170cf] update the gitignore file
 1 file changed, 2 insertions(+), 1 deletion(-)
PS C:\Users\besta\app\github_actions_gcp_07tutorial> git push origin develop
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 12 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 322 bytes | 322.00 KiB/s, done.
Total 3 (delta 2), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (2/2), completed with 2 local objects.
To https://github.com/daichi213/github_actions_gcp_07tutorial.git
   33b0737..ae170cf  develop -> develop
PS C:\Users\besta\app\github_actions_gcp_07tutorial>
```

## vagrant エラー

vagrant コマンドを実行した際に以下のように Encoding エラーが発生した。

```powershell
PS C:\Users\besta\app\github_actions_gcp_07tutorial\server_conf\vagrant> vagrant
Traceback (most recent call last):
        30: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/bin/vagrant:194:in `<main>'
        29: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/bin/vagrant:194:in `new'
        28: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/environment.rb:178:in `initialize'
        27: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/environment.rb:984:in `process_configured_plugins
        26: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/environment.rb:956:in `find_configured_plugins'
        25: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/environment.rb:944:in `guess_provider'
        24: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/environment.rb:347:in `default_provider'
        23: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/registry.rb:48:in `each'
        22: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/registry.rb:48:in `each'
        21: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/registry.rb:49:in `block in each'
        20: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/environment.rb:361:in `block in default_provider'
        19: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/plugins/providers/hyperv/provider.rb:20:in `usable?'
        18: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/platform.rb:84:in `windows_admin?'
        17: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/platform.rb:82:in `block in windows_admin?'
        16: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/powershell.rb:113:in `execute_cmd'
        15: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/powershell.rb:212:in `validate_install!'
        14: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/powershell.rb:191:in `version'
        13: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/subprocess.rb:22:in `execute'
        12: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/subprocess.rb:154:in `execute'
        11: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/safe_chdir.rb:24:in `safe_chdir'
        10: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/safe_chdir.rb:24:in `synchronize'
         9: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/safe_chdir.rb:25:in `block in safe_chdir'
         6: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/vagrant-2.2.19/lib/vagrant/util/subprocess.rb:155:in `block in execute'
         5: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/childprocess-4.1.0/lib/childprocess/abstract_process.rb:81:in `start'
         4: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/childprocess-4.1.0/lib/childprocess/windows/process.rb:70:in `launch_process
         3: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/childprocess-4.1.0/lib/childprocess/windows/process_builder.rb:28:in `start'
         2: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/childprocess-4.1.0/lib/childprocess/windows/process_builder.rb:67:in `createter'
         1: from C:/HashiCorp/Vagrant/embedded/gems/2.2.19/gems/childprocess-4.1.0/lib/childprocess/windows/process_builder.rb:44:in `to_wid
```

### 原因

[以下のようにコンソールの文字コードを SHIFT JIT へ変更することによって解決した。](https://qiita.com/yukinissie/items/969db7110845f66e80ec)
[POWERSHELL の場合は以下のようにして変更する。](https://qiita.com/Yorcna/items/d015ebe4fae50882e3a1)

```
PS C:\Users\besta\app\github_actions_gcp_07tutorial> $OutputEncoding.EncodingName
US-ASCII
PS C:\Users\besta\app\github_actions_gcp_07tutorial> $OutputEncoding = [console]::OutputEncoding;
PS C:\Users\besta\app\github_actions_gcp_07tutorial> $OutputEncoding.EncodingName
日本語 (シフト JIS)
PS C:\Users\besta\app\github_actions_gcp_07tutorial\server_conf\vagrant> vagrant status
Current machine states:

ansible                   not created (virtualbox)
jenkins                   not created (virtualbox)

This environment represents multiple VMs. The VMs are all listed
above with their current state. For more information about a specific
VM, run `vagrant status NAME`.
```

## Ansible で apt install する際の Not found

Ansible で docker をインストールする設定を Playbook で以下のように行っていた。

```yml
---
- name: add docker apt repository
  apt_repository:
    update_cache: yes
    # repo: deb https://pkg.jenkins.io/debian-stable binary/
    repo: "deb [arch=amd64] https://download.docker.com/linux/ubuntu jammy stable/"
    state: present

- name: be sure docker-ce repository is installed
  apt:
    update_cache: yes
    name:
      - docker-ce
```

### 原因

Playbook を実行した際に、以下のようなエラーが発生し、docker-ce のインストールに失敗した。

```bash
...
TASK [common : be sure docker-ce repository is installed] **********************************************************************************fatal: [192.168.17.2]: FAILED! => {"changed": false, "msg": "No package matching 'docker-ce' is available"}
...
```

ansible の apt_repository は直下に存在するパッケージファイルのみしか読み込まないため、以下のように設定を修正することでエラーを解決した。

```yml
- name: add docker apt repository
  apt_repository:
    update_cache: yes
    repo: "deb https://download.docker.com/linux/ubuntu jammy stable binary-amd64/"
    state: present
```
