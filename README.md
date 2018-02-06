# Overview
- scheduling tweets bot
    - `gs2_ticket_status`
    - `notify_if_music_engine_tweets`
    - ...

# Prepare
```bash
$ bundle install
```

# Required
- Redis
- `.env`
    - TWITTER_ACCESS_TOKEN
    - TWITTER_ACCESS_TOKEN_SECRET
    - TWITTER_CONSUMER_KEY
    - TWITTER_CONSUMER_SECRET
    - REDIS_HOSTNAME
    - REDIS_PORT
- set cron
    - for instance, use [Whenever](https://github.com/javan/whenever)

# TODO
- RSpec

# LICENSE
[MIT LICENSE](/LICENSE)
