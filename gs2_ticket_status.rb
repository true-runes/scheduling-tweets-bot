require 'twitter'
require 'redis'
require 'dotenv'
require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'nokogiri'
require 'json'

class Gs2TicketStatus
  def initialize
    Dotenv.load(File.expand_path('../.env', __FILE__))

    @twitter_client = Twitter::REST::Client.new do |config|
      config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
      config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
      config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    end

    @redis = Redis.new(host: ENV['REDIS_HOSTNAME'], port: ENV['REDIS_PORT'])
    @redis_key = 'gs2_ticket_status'
    @before_status = JSON.parse(@redis.get(@redis_key))['status']
  end

  def session
    Capybara.register_driver :chrome do |app|
      Capybara::Selenium::Driver.new(app, browser: :chrome)
    end

    Capybara.register_driver :headless_chrome do |app|
      capabilities = Selenium::WebDriver::Remote::Capabilities.chrome(
        chromeOptions: { args: %w(headless disable-gpu window-size=1920,1080) }
      )
      Capybara::Selenium::Driver.new(
        app,
        browser: :chrome,
        desired_capabilities: capabilities
      )
    end

    Capybara.javascript_driver = :headless_chrome

    @session = Capybara::Session.new(:headless_chrome)
  end

  def check
    session

    gs2_music_engine_eplus_uri = 'http://sort.eplus.jp/sys/T1U14P0010163P0108P002247809P0050001P006001P0030001'
    @session.visit(gs2_music_engine_eplus_uri)

    doc = Nokogiri::HTML.parse(@session.html, nil, 'UTF-8')
    nodes = doc.xpath(%Q(//p[@class="accept-pre"]))
    nodes[0].text
  end

  def time_class_to_string_ja(time_type)
    time_type.strftime("%Y/%m/%d(#{%w(日 月 火 水 木 金 土)[time_type.wday]}) %X") #=> 2018/01/22(月) 17:18:43
  end

  def update_status?(before_status)
    return true if JSON.parse(@redis.get(@redis_key))['status'] != before_status
    false
  end

  def check_and_set_to_redis
    redis_value = {
      status: check,
      last_checked_at: Time.now,
    }
    @redis.set(@redis_key, redis_value.to_json)
  end

  def tweet_message
    now_datetime_ja           = time_class_to_string_ja(Time.now)
    now_status                = JSON.parse(@redis.get(@redis_key))['status']
    message_of_judging_change = status_change_message(update_status?(@before_status))

    <<~EOM
      @budehuc
      #{now_datetime_ja} 現在のチケ状況は以下のとおりです
      #{now_status}（#{message_of_judging_change}）
    EOM
  end

  def status_change_message(boolean)
    return '前回チェック時から変更あり' if boolean
    '前回チェック時から変更なし'
  end

  def string_to_time_class(string)
    Time.parse(string)
  end

  def main
    check_and_set_to_redis
    @twitter_client.update(tweet_message)
  end
end

obj = Gs2TicketStatus.new
obj.main
