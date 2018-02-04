require 'twitter'
require 'redis'
require 'active_record'
require 'dotenv'

class NotifyIfMusicEngineTweets
  def initialize
    Dotenv.load(File.expand_path('../.env', __FILE__))

    @twitter_client = Twitter::REST::Client.new do |config|
      config.access_token        = ENV['TWITTER_ACCESS_TOKEN']
      config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
      config.consumer_key        = ENV['TWITTER_CONSUMER_KEY']
      config.consumer_secret     = ENV['TWITTER_CONSUMER_SECRET']
    end

    @redis = Redis.new(host: ENV['REDIS_HOSTNAME'], port: ENV['REDIS_PORT'])
    @redis_key = 'musicengine_latest_tweet_id'
    @latest_tweet_id = @redis.get(@redis_key)
    @latest_tweet_id = 1 if @latest_tweet_id.nil? # HACK: 不自然

    @tweet_object_of_max_tweet_id = nil
  end

  def user_object(user_id_or_screen_name) # Integer or String
    @twitter_client.user(user_id_or_screen_name)
  end

  def update_tweet_object_of_max_tweet_id(tweet)
    @tweet_object_of_max_tweet_id = tweet if @tweet_object_of_max_tweet_id.nil? || tweet.id.to_i > @tweet_object_of_max_tweet_id.id.to_i # HACK: 判定文が長すぎて読みにくい
  end

  def set_max_tweet_id_to_redis
    unless @tweet_object_of_max_tweet_id.nil? # 新しいツイートが無い場合は書き込みに行かない
      @redis.set(@redis_key, @tweet_object_of_max_tweet_id.id) if @tweet_object_of_max_tweet_id.id.to_i > @latest_tweet_id.to_i
    end
  end

  # @musicengine_tw: 726040937550368769
  def new_tweets
    musicengine = user_object(726040937550368769) # TODO: マジックナンバー
    new_tweets = []

    @twitter_client.user_timeline(musicengine, { since_id: @latest_tweet_id, count: 5 }).each do |tweet|
      new_tweets << tweet
      update_tweet_object_of_max_tweet_id(tweet) # ここで実行しておかないと再びどこかでループさせないといけなくなる
    end

    new_tweets
  end

  def tweet_is_reply?(tweet)
    # #user_mentions? で判別すると RT が問答無用で除外されてしまう
    return false if tweet.in_reply_to_status_id.nil? # Twitter::NullObject
    true
  end

  def tweet_header
    "@budehuc MUSICエンジンの新規ツイート\n\n"
  end

  def tweet_body(tweet)
    text  = tweet.full_text.truncate(35) # HACK: マジックナンバー
    uri   = tweet.uri

    <<~EOM
      #{text}
      #{uri}
    EOM
  end

  def notify(tweets)
    tweets.each do |tweet|
      unless tweet_is_reply?(tweet)
        tweet_message = "#{tweet_header}#{tweet_body(tweet)}"
        @twitter_client.update(tweet_message)
      end
    end
  end

  def main
    notify(new_tweets)
    set_max_tweet_id_to_redis
  end
end

obj = NotifyIfMusicEngineTweets.new
obj.main
