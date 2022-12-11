# Package

version       = "0.1.0"
author        = "Антон Панов"
description   = "telegram rss reader"
license       = "MIT"
srcDir        = "src"
bin           = @["capp_telegram_news_bot_nim"]


# Dependencies

requires "nim >= 1.7.3"
requires "norm >= 2.6.0"
requires "dotenv >= 2.0.1"
requires "FeedNim >= 0.2.1"
requires "regex >= 0.1.0"
