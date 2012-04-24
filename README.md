# What is TweetGatherer?

Twitter does not save your tweets forever. TweetGatherer emails you your own
tweets, retweets, and @reply-conversations for the past day. You can keep these
emails as an archive, automatically send them to your blog as posts, etc.


# Usage

Tested in Ruby 1.8.

    $ tweet_gatherer --help
    
    Usage: tweet_gatherer [options]
        -d, --date DATE                  Date (defaults to today)
            --yesterday                  Gather tweets from yesterday
        -n, --num NUM                    Number of tweets to get per call
        -t, --to EMAIL                   Email specified address; ignore config file
        -f, --[no-]dry-run               Print email to STDOUT instead of sending it
        -h, --help                       Show this help message
    
    Settings are read from tweet_gatherer.yml

For example, email yourself today's or yesterday's tweets:

    tweet_gatherer --to youremail@example.com

    tweet_gatherer --to youremail@example.com --yesterday

Or email yourself some other day's tweets:

    tweet_gatherer --to youremail@example.com --date 2011-12-31


# Installation

## Prerequisites

`gem install -v 1.1.2 twitter`

_(Yes, I know this is quite an old version of the API. It's what was out when I
first wrote this program for myself, and it still works.)_

## Create a Twitter Application

You will run your own Twitter application for yourself.
[Create an application][1]:

 1. use any _name_, _description_, and _website_ you want
 2. leave _callback URL_ blank
 3. submit
 4. from the _OAuth settings_ section on the next page, note the values of:
     - **consumer key**
     - **consumer secret**
 5. click the _Create my access token_ button at the bottom of the page (and
    reload the page if it doesn't automatically update). Read-only access is all
    you need. Note the values of:
     - **access token**
     - **access token secret**

**DO NOT SHARE THESE VALUES.** Do not submit files with these values to Github.
They are like your password; anyone with access to these values can do read-only
actions as though they were you. This includes reading any private tweets you
may have! If you accidentally share the values, go to your Twitter application's
page and reset the keys.

## Download

`git clone git://github.com/Arthaey/TweetGatherer.git`

## Configuration

TweetGatherer is configured via a [YAML][3] file. Edit tweet\_gatherer.yml
with your own settings.

### Twitter Settings

Get the values from your Twitter application in the step above and include them
in the _twitter_ section of the configuration file:

    twitter:
      consumer_key: "[consumer_key]"
      consumer_secret: "[consumer_secret]"
      oauth_token: "[oauth_token]"
      oauth_token_secret: "[oauth_token_secret]"

These 4 values are _required_.

There is also one optional setting under the _twitter_ section:

      ignore_hashtags:
        - ignore
        - private
        - whateveryouwant

Any tweets that contain one of these hashtags will be ignored by TweetGatherer.

### Email Settings

The _email_ section of the configuration file is optional. If you do not include
a _to_ setting, you must pass a `--to you@example.com` argument to the program.
The _from_ setting is also optional, and defaults to what you see below:

    emails:
      to: "Your Email <you@example.com>"
      from: "TweetGatherer <tweet_gatherer@arthaey.com>"
      use_sendmail: false

If you are running this script on a hosted server that requires you to use SMTP
authentication, set _use_sendmail_ to _true_ and see if that works for you. (For
example, this is necessary for Dreamhost servers.)

### Playing Nicely With Git

If you used Git to clone TweetGatherer, you'll notice that it now marks
tweet\_gatherer.yml as modified. However, **you should not commit changes to
tweet\_gatherer.yml**. To tell git to ignore your changes, run this:

    git update-index --assume-unchanged tweet_gatherer.yml

## Automatically Run TweetGatherer Every Night

Use cron to run TweetGatherer every night. For example, run `crontab -e` and
include something like the following in your crontab file:

    # email yourself today's tweets at the 11:58 PM
    58 23 * * * /path/to/tweet_gatherer --to youremail@example.com

By default, TweetGatherer uses the current date as the day to gather tweets.
Therefore, you should run the program just before midnight.


# Troubleshooting

## Invalid / expired Token

If you see
`GET https://api.twitter.com/1/account/verify_credentials.json: 401: Invalid / expired Token`,
it means that your authorization settings in the tweet\_gatherer.yml settings
file are either missing or incorrect. Double-check them.

## 502 errors

This seems to happen once you have more than ~2500 tweets total. Try passing an
argument of `--num 100` or `--num 50` if you start seeing this error. See the
[Twitter dev forum][2] for more details.


# TODO

 - include @mentions that you didn't reply to
 - include direct messages
 - document all possible config settings
 - support non-HTML email formatting
 - use current version of Twitter gem


[1]: https://dev.twitter.com/apps/new
[2]: https://dev.twitter.com/discussions/3236
[3]: http://en.wikipedia.org/wiki/YAML
