require "rubygems"
require "erb"
require "net/smtp"

class Emailer
  # TODO: support non-HTML formatting

  FROM_DEFAULT = "TweetGatherer <tweet_gatherer@arthaey.com>"

  SECTION_TITLE_DEFAULTS = {
    :tweets =>   "What I had to say",
    :replies =>  "Conversations I participated in",
    :retweets => "What I found interesting or amusing",
  }

  def initialize(config, tweets, screen_name, subject = "Today's Tweets")
    # set any missing config values to their defaults
    config["from"] ||= FROM_DEFAULT
    section_titles = config["section_titles"] || {}
    section_titles["tweets"]   ||= SECTION_TITLE_DEFAULTS[:tweets]
    section_titles["replies"]  ||= SECTION_TITLE_DEFAULTS[:replies]
    section_titles["retweets"] ||= SECTION_TITLE_DEFAULTS[:retweets]

    if config["to"].nil?
      abort("Must define To: address via --to or the config file.")
    end

    @from_email = config["from"]
    @to_email = config["to"]
    @subject = subject
    @screen_name = screen_name

    @tweets_list   = make_list(tweets[:tweets],   section_titles["tweets"])
    @replies_list  = make_list(tweets[:replies],  section_titles["replies"])
    @retweets_list = make_list(tweets[:retweets], section_titles["retweets"])
  end

  def text
    <<-EMAIL.gsub(/^ {6}/, "")
      From: #{@from_email}
      To: #{@to_email}
      MIME-Version: 1.0
      Content-Transfer-Encoding: quoted-printable
      Content-type: text/html; charset=utf-8
      Subject: #{@subject}

      #{@tweets_list}

      #{@replies_list}

      #{@retweets_list}
    EMAIL
  end

  def send
    Net::SMTP.start("localhost") do |smtp|
      smtp.send_message(text, @from_email, [@to_email])
    end
  end

  private
  def make_list(tweets, title)
    return "" if tweets.empty?

    tweet_list = (title.nil? ? "" : "<h4>#{title}</h4>\n")
    tweet_list << "<ul class='tweets'>\n"
    tweets.each do |tweet|
      tweet_list << format_tweet(tweet)
    end
    tweet_list << "</ul>"
  end

  private
  def format_tweet(tweet)
    css_class = (tweet.conversation_start ? "conversation-start " : "")
    css_class << (tweet.conversation ? "conversation " : "")
    css_class << (tweet.user.screen_name ? "others-tweet" : "own-tweet")
    "<li class='#{css_class}' data-tweet-id='#{tweet.id}'>#{linkify_tweet(tweet)} #{external_link(tweet)}</li>\n"
  end

  private
  def linkify_tweet(tweet)
    # must split in a Unicode-aware way, or else Ruby 1.8 won't correctly find the
    # anchors or insert the links around them
    chars = tweet.text.split(//u)

    entities = tweet.entities.map { |e| e.last }.flatten.reject { |e| e.empty? }
    entities = entities.sort_by { |e| e["indices"].first }.reverse
    entities.each do |entity|
      i = entity["indices"].first
      j = entity["indices"].last - 1
      anchor = chars[i..j]

      url = entity["url"]
      expanded_url = entity["expanded_url"]
      screen_name = entity["screen_name"]
      hashtag = entity["text"]

      if expanded_url || url
        chars[i..j] = "<a href='#{expanded_url || url}'>#{anchor}</a>"
      elsif screen_name
        chars[i..j] = "@<a href='http://twitter.com/#{screen_name}'>#{anchor[1..-1]}</a>"
      elsif hashtag
        chars[i..j] = "#<a href='http://twitter.com/search?q=#{ERB::Util.url_encode(hashtag)}'>#{anchor[1..-1]}</a>"
      end
    end

    html = ""
    screen_name = tweet.user.screen_name
    if screen_name
      html = "<span class='others-name'>@<a href='http://twitter.com/#{screen_name}'>#{screen_name}</a> said:</span> "
    elsif tweet.conversation
      html = "<span class='others-name'>@<a href='http://twitter.com/#{@screen_name}'>I</a> said:</span> "
    end

    html + chars.join
  end

  private
  def external_link(tweet)
    url = "http://twitter.com/#{@screen_name}/status/#{tweet.id}"
    "<span class='tweet-link'>[<a href='#{url}'>#{tweet.created_at_local}</a>]</span>"
  end

end
