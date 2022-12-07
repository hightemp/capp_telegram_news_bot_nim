#!/bin/bash

export CFILE=capp_telegram_news_bot_nim

nim musl \
    --passL:-static \
    -d:sqlite3 \
    --dynlibOverride:sqlite3 \
    -d:pcre \
    -d:openssl \
    ./src/$CFILE.nim
mv ./src/$CFILE ./

if [ "$?" != "0" ]; then
    echo "====================================================="
    echo "ERROR"
    echo
    exit 1
fi

echo 
echo "[+] BUILD"