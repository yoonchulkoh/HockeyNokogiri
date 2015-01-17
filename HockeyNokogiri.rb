require 'open-uri'
require 'nokogiri'
require 'mechanize'
require 'csv'
require 'time'

class HockeyNokogiri

  CONFIG_FILE_NAME = 'config.yml'

  @config
  @agent
  @debug

  def execute(debug=false)
    @debug = debug
    puts 'debug mode.' if @debug
    init
    doc = get_document
    do_login
    rel_list, description_list = get_detail_page_urls
    crash_list = get_crash_list(rel_list, description_list)
    export_csv(crash_list)
  end
  
  def init
    load_config
    if error = check_config
      puts error
      return
    end
    @agent = Mechanize.new
  end

  def load_config
    @config = YAML.load_file(CONFIG_FILE_NAME)
  end

  def check_config
    ['app_id', 'version', 'email', 'password'].each do |key|
      if @config[key].nil? || @config[key].empty?
        return "#{key} is not found in config file."
      end
    end
    return nil
  end

  def get_document
    charset = nil
    html = open(get_url) do |f|
      charset = f.charset
      f.read
    end
    doc = Nokogiri::HTML.parse(html, nil, charset)
  end

  def get_url
    "https://rink.hockeyapp.net/manage/apps/#{@config['app_id']}/app_versions/#{@config['version']}/crash_reasons?per_page=50&order=desc&sort_by=count&type=symbols"
  end

  def do_login
    puts '### ログイン開始'
    @agent.get(get_url) do |page| 
      login_result = page.form_with(id: 'sign_in') do |login|
        login['user[email]'] = @config['email']
        login['user[password]'] = @config['password']
      end.submit
    end
    puts '### ログイン完了'
  end

  def get_detail_page_urls
    puts '### 詳細ページURL取得開始'
    rel_list = []
    description_list = []

    # ページング判定は面倒なのでとりあえずMAX10までで
    1.upto(10) do |i|
      res = get_detail_page_urls_per_page(@agent, get_url, i)
      next unless res
      rel_list.concat(res[0])
      description_list.concat(res[1])
      break if @debug
    end
    puts "### 詳細ページURL取得完了 #{rel_list.count}件"
    return rel_list, description_list
  end

  def get_detail_page_urls_per_page(agent, url, page_num)
    rel_list = []
    description_list = []
    agent.get(url + "&page=#{page_num}") do |page|
      html = Nokogiri::HTML(page.body)
      return false if html.css('table.crash_reasons tr') == nil
      html.css('table.crash_reasons tr').each_with_index do |tr, i|
        if tr['rel'] == nil
          next
        else
          rel = tr['rel']
          rel_list << rel
        end
        description_list << tr.css('td.description').text.strip.gsub(/\n/, "") unless tr.css('td.description') == nil
        break if @debug
      end
    end
    return rel_list, description_list
  end

  def get_crash_list(rel_list, description_list)
    crash_list = []
    rel_list.each_with_index do |url, i|
      puts "#{i+1}件/#{rel_list.count}件"
      reason = description_list[i]
      1.upto(10) do |i|
        res = get_crash_list_per_page(@agent, url, i, reason)
        next unless res
        crash_list.concat(res)
        break if @debug
      end
    end
    crash_list
  end

  def get_crash_list_per_page(agent, url, page, reason)
    crash_list = []
    agent.get("https://rink.hockeyapp.net#{url}?order=desc&per_page=50&sort_by=user&type=crashes" + "&page=#{page}") do |page|
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
              date_value = span.attr('data-value')
              time = Time.parse(date_value).localtime.strftime('%Y-%m-%d %H:%M:%S')
              tds << time
            end
          end
        end
        tds << reason
        tds << "https://rink.hockeyapp.net#{url}"
        crash_list << tds unless tds.nil?
        break if @debug
      end
    end
    return crash_list
  end

  def export_csv(crash_list)
    puts '### CSV出力開始'
    file_name = "crash_report/crash_report_#{DateTime.now.strftime("%Y%m%d%H%M%S")}"
    CSV.open("#{file_name}.csv", "wb", force_quotes: true) do |csv|
      csv << ['Device','OS','Jailbroken Device','Description Attached','User','Contact','Date','-','Description', 'URL']
      crash_list.each do |crash|
        csv << crash
      end
    end
    # mac用ファイル出力
    # File.open("#{file_name}_utf16.csv", 'w') do |f|
    #   bom = "\xFF\xFE".force_encoding("UTF-16LE")
    #   f.print bom # BOM
    #   f.puts File.open(file_name).read.encode("UTF-16LE")
    # end
    puts '### CSV出力完了'
  end

end

hockeyNokogiri = HockeyNokogiri.new
debug = ARGV[0] == '-d' || ARGV[0] == '--debug'
hockeyNokogiri.execute(debug)