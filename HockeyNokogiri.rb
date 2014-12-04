require 'open-uri'
require 'nokogiri'
require 'mechanize'
require 'csv'

$config = YAML.load_file('config.yml')

if $config['app_id'].nil? || $config['app_id'].empty?
  puts "app_id is not found in config file."
  exit
end
if $config['version'].nil? || $config['version'].empty?
  puts "version is not found in config file."
  exit
end
if $config['email'].nil? || $config['email'].empty?
  puts "email is not found in config file."
  exit
end
if $config['password'].nil? || $config['password'].empty?
  puts "password is not found in config file."
  exit
end

# スクレイピング先のURL
url = "https://rink.hockeyapp.net/manage/apps/#{$config['app_id']}/app_versions/#{$config['version']}/crash_reasons?per_page=50&order=desc&sort_by=count&type=symbols"

charset = nil
html = open(url) do |f|
  charset = f.charset
  f.read
end

# htmlをパース(解析)してオブジェクトを生成
doc = Nokogiri::HTML.parse(html, nil, charset)


agent = Mechanize.new

puts '### ログイン開始'

agent.get(url) do |page| 
  # ログインする
  login_result = page.form_with(id: 'sign_in') do |login|
    login['user[email]'] = $config['email']
    login['user[password]'] = $config['password']
  end.submit
end

puts '### ログイン完了'

puts '### 詳細ページURL取得開始'

# 詳細ページURLを全て取得する
$rel_list = []
$description_list = []

def get_rel_list(agent, url, page)
  agent.get(url + "&page=#{page}") do |page|
    html = Nokogiri::HTML(page.body)
    return false if html.css('table.crash_reasons tr') == nil
    html.css('table.crash_reasons tr').each do |tr|
      if tr['rel'] == nil
        next
      else
        rel = tr['rel']
        $rel_list << rel
      end
      $description_list << tr.css('td.description').text.strip.gsub(/\n/, "") unless tr.css('td.description') == nil
    end
  end
  return true
end

# ページング判定は面倒なのでとりあえずMAX10までで
1.upto(10) do |i|
  res = get_rel_list(agent, url, i)
  next unless res
end

puts "### 詳細ページURL取得完了 #{$rel_list.count}件"


puts '### クラッシュ一覧取得開始'

# 詳細ページからテーブル内容を取得する
$crash_list = []

def get_crash_list(agent, url, page, reason)
  agent.get(url + "&page=#{page}") do |page|
    html = Nokogiri::HTML(page.body)
    return false if html.css('table.crashes tr') == nil
    html.css('table.crashes tr.crash').each do |tr|
      tds = []
      tr.css('td').each do |td|
        unless td.text.strip.empty?
          tds << td.text.strip.gsub(/\n/, "")
        else
          span = td.css('span')
          if span.nil? || span.empty?
            tds << ""
          else
            tds << span.attr('data-value')
          end
        end
      end
      tds << reason
      $crash_list << tds unless tds.nil?
    end
  end
  return true
end

$rel_list.each_with_index do |url, i|
  puts "#{i+1}件/#{$rel_list.count}件"
  reason = $description_list[i]
  1.upto(10) do |i|
    res = get_crash_list(agent, "https://rink.hockeyapp.net#{url}?order=desc&per_page=50&sort_by=user&type=crashes", i, reason)
    next unless res
  end
end

puts '### クラッシュ一覧取得終了'

puts '### CSV出力開始'

CSV.open("crash_report_#{DateTime.now.strftime("%Y%m%d%H%M%S")}.csv", "wb") do |csv|
  csv << ['Device','OS','Jailbroken Device','Description Attached','User','Contact','Date','-','Description']
    $crash_list.each do |crash|
        csv << crash
    end
end

puts '### CSV出力完了'