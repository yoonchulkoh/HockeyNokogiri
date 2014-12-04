HockeyNokogiri
==============

HockeyAppサイトをスクレイピングしてクラッシュレポート一覧を取得します。  
全て取得すると重いのでバージョン指定のみ対応しています。

# 使い方

## configを設定します
$ cp config_sample.yml config.yml

例）
クラッシュレポートを取得したいアプリ、バージョンのURLが下記の場合
https://rink.hockeyapp.net/manage/apps/99999/app_versions/1
```
app_id: '99999' 
version: '1'
email: '[ログインemail]'
password: '[ログインパスワード]'
```
## 叩きます
$ ruby HockeyNokogiri.ruby
