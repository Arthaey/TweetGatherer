require "rubygems"
require "date"
require "json"

# TODO: use current version of Twitter gem
#
# docs for version 1.1.2:
# https://github.com/jnunemaker/twitter/tree/dffe31cc3e1fb6074afd1c00884e29e1e60ad5bd
#
gem "twitter", "=1.1.2"
require "twitter"

require "lib/tweet_comparator"

class TweetGatherer

  NOW = DateTime.now

  # Per the Twitter API documentation, the maximum *allowed* value is 200.
  # However, according to https://dev.twitter.com/discussions/3236 this can "put
  # extra stress on the system" and makes a 502 error more likely. Twitter devs
  # suggest using a lower number, like 100, so that errors are less likely.
  # So you may want to call this script with --num 100 if you start seeing 502s.
  MAX_TWEETS = 200

  def initialize(config, yyyy_mm_dd = nil, num_tweets = MAX_TWEETS)
    # authentication with Twitter
    @consumer_key       = config["consumer_key"]
    @consumer_secret    = config["consumer_secret"]
    @oauth_token        = config["oauth_token"]
    @oauth_token_secret = config["oauth_token_secret"]

    @ignore_hashtags = config["ignore_hashtags"]
    @num_tweets = num_tweets

    # timezone fun
    offset = NOW.strftime("%Z")
    date_str = if yyyy_mm_dd
                 "#{yyyy_mm_dd}T00:00:00#{offset}"
               else
                 NOW.strftime("%Y-%m-%dT00:00:00#{offset}")
               end

    @date = DateTime.parse(date_str)

    configure_client
  end

  def tweets
    fetch_all_tweets! unless @tweets
    @tweets
  end

  def retweets
    fetch_all_tweets! unless @retweets
    @retweets
  end

  def replies
    fetch_all_tweets! unless @replies
    @replies
  end

  def date
    @date.strftime("%F")
  end

  private ######################################################################

  def configure_client
    Twitter.configure do |config|
      config.consumer_key       = @consumer_key
      config.consumer_secret    = @consumer_secret
      config.oauth_token        = @oauth_token
      config.oauth_token_secret = @oauth_token_secret
    end
  end

  def fetch_all_tweets!
    timeline_options = {
      :trim_user => true,
      :include_entities => true,
      :count => @num_tweets,
    }
    
    my_timeline = []
    rt_timeline = []
    begin
      my_timeline = Twitter.user_timeline(timeline_options)
      rt_timeline = Twitter.retweeted_by_me(timeline_options)
    rescue Twitter::Unauthorized => e
      abort(e.message)
    end

    timeline = my_timeline + rt_timeline

    @tweets    = []
    @replies   = []
    @retweets  = []

    # only keep this day's tweets
    tweets = timeline.reject do |t|
      local_time = local_time!(t)
      # Timeline of tweets, and which dates to keep:
      #
      # <--- ... (before DATE) ... (DATE) ... (DATE+1) ... (after DATE+1) ... --->
      #
      #      [.......reject.......][.......KEEP......][........reject.......]
      #
      local_time < @date || local_time > (@date+1)
    end

    # order oldest to newest, where tweet ids are monotonically increasing
    tweets = tweets.sort_by(&:id)

    tweets.each do |tweet|
      hashtags = tweet.entities["hashtags"].map { |e| e["text"] }

      # check for any of the hashtags that are supposed to be ignored
      next unless (hashtags & @ignore_hashtags).empty?

      # find replies
      if tweet.in_reply_to_status_id
        # get entire conversation of replied-to tweet
        convo = [tweet]
        t = tweet.clone
        while (t.in_reply_to_status_id)
          begin
            t = Twitter.status(t.in_reply_to_status_id, :include_entities => true)
            local_time!(t)
            convo << t
          rescue Twitter::NotFound
            # if the tweet has since been deleted, there's not much we can do
          end
        end

        # TODO:look for any reply to my tweet
        # Twitter.mentions(:since_id => tweet.id, :include_entities => true)

        convo.reverse!
        convo.first.conversation_start = true
        convo.each do |convo_tweet|
          convo_tweet.conversation = true
          # TODO: remove hacky workaround for duplicated tweets in conversations
          convo_tweet.extend(TweetComparator)
        end
        @replies += convo

      # find retweets
      elsif tweet.text.start_with?("RT ") || tweet.text.match(/\bvia\b/)
        @retweets << tweet

      # find normal, original tweets
      else
        @tweets << tweet
      end
    end

    # TODO: remove hacky workaround for duplicated tweets in conversations
    @replies.uniq!
  end

  def local_time!(tweet)
    utc_time = DateTime.parse(tweet.created_at)
    local_time = utc_time.new_offset(NOW.offset)
    tweet.created_at_local = local_time.strftime("%l:%M %p")
    local_time
  end

end
