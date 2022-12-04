import FeedNim
import regex
import dotenv, os
import strutils
import times

load()
var RSS_LINK = getEnv("RSS_LINK")


var oRSS = getRSS(RSS_LINK)

var oSeq = oRSS.items
for iIndex, oItem in oSeq:
    echo oItem.title
    echo oItem.link
    echo oItem.pubDate
    let dt = parse(oItem.pubDate, "ddd, d MMM yyyy hh:mm:ss ZZZ")
    echo $(dt)
    echo oItem.description.replace(re"</p>", "\n").replace(re"<[^>]+>", "")