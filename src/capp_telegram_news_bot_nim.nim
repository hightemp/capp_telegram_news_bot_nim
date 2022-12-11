import logging, options, strutils
import os
import dotenv
import FeedNim
import FeedNim/rss
import regex
import strutils
import times
import db_sqlite
import httpclient
import json

load()

let argc = paramCount()
let argv = commandLineParams()
let programName = getAppFilename()

proc main() =
  try:
    var RSS_LINK = getEnv("RSS_LINK")
    var TELEGRAM_BOT_KEY = getEnv("TELEGRAM_BOT_KEY")
    var TELEGRAM_BOT_UPDATE_TIMEOUT = getEnv("TELEGRAM_BOT_UPDATE_TIMEOUT").parseInt()
    var CHANNEL_ID = cast[uint64](getEnv("TELEGRAM_BOT_CHANNEL_ID").parseInt())
    putEnv("DB_HOST", getEnv("DB_HOST", "./db.sqlite.db"))
    var DB_HOST = getEnv("DB_HOST")
    const telegramBaseUrl: string = "https://api.telegram.org/bot"

    var L = newConsoleLogger(fmtStr="$levelname, [$time] ")
    addHandler(L)

    let bot = newTeleBot(TELEGRAM_BOT_KEY)

    var db = open(DB_HOST, "", "", "")

    db.exec(sql"""
      CREATE TABLE IF NOT EXISTS rss_threads (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          pubdate VARCHAR(255) NOT NULL,
          title VARCHAR(4000) NOT NULL,
          link VARCHAR(4000) NOT NULL,
          description VARCHAR(4000) NOT NULL
      )
    """)

    if argc>0 and argv[0]=="clear_db":
      db.exec(sql"""DELETE FROM rss_threads""")
      echo "[!] database cleaned"
    
    var iLastTimestamp = 0
    
    var sTimestamp = db.getValue(sql"SELECT IFNULL(timestamp, '0') FROM rss_threads ORDER BY timestamp DESC LIMIT 1")
    
    if sTimestamp!="":
      iLastTimestamp = sTimestamp.parseInt()
    
    echo "[!] Last timestamp: " & $sTimestamp & " " & $iLastTimestamp

    proc sendMessage(botToken: string, chatId: uint64, text: string, parseMode: string = "HTML"): string =
      let client = newHttpClient()
      client.headers = newHttpHeaders({ "Content-Type": "application/json" })
        
      let 
        body = %*{"chat_id": chatId, "text": text, "parse_mode": parseMode}
        url = telegramBaseUrl & botToken & "/sendMessage"

      # echo $body
      let response = client.request(url, httpMethod = HttpPost, body = $body)
      client.close()

      return response.body
    
    proc fnSend(oItem: RSSItem, sDesc: string): string = 
      var sMessage = "<a href=\"" & oItem.link & "\">" & oItem.title & "</a>\n" & sDesc
      # discard await bot.sendMessage(CHANNEL_ID, sMessage)
      echo "[!] Message: " & sMessage

      # echo "[>]", 
      return sendMessage(TELEGRAM_BOT_KEY, CHANNEL_ID, sMessage)

    proc fnAsyncSendRSSMessage(oItem: RSSItem): bool = 
      var sDesc = oItem.description
        .replace(re"</p>", "\n")
        .replace(re"<[^>]+>", "")
        .replace(re"\n+\s*", "\n")
        .replace("&nbsp;", " ")
      let dt = parse(oItem.pubDate, "ddd, d MMM yyyy hh:mm:ss ZZZ")
      var iPubTimestamp = cast[int](dt.toTime().toUnix())

      if (iPubTimestamp > iLastTimestamp):
        echo "[!] Added: " & $iPubTimestamp & " " & oItem.title
        db.exec(
          sql"INSERT INTO rss_threads (timestamp, pubdate, title, link, description) VALUES (?, ?, ?, ?, ?)", 
          iPubTimestamp,
          oItem.pubDate,
          oItem.title,
          oItem.link,
          sDesc
        )

        var sResponse = fnSend(oItem, sDesc)

        # echo sResponse
        echo "[OK] " & $iLastTimestamp & " " & $iPubTimestamp
        iLastTimestamp = iPubTimestamp

        return true
      return false

    proc fnPostForUpdates() =
      while true:
        var oRSS = getRSS(RSS_LINK)

        var oSeq = oRSS.items
        for iIndex in countdown(high(oSeq),low(oSeq)):
          var oItem = oSeq[iIndex]
          echo "[START] " & $iIndex
          if not fnAsyncSendRSSMessage(oItem):
            continue

        echo "[SLEEP] " & $(TELEGRAM_BOT_UPDATE_TIMEOUT/1000) & "s"
        sleep(TELEGRAM_BOT_UPDATE_TIMEOUT)

    fnPostForUpdates()
  except CatchableError as e:
    echo "ERROR: " & e.msg

main()
