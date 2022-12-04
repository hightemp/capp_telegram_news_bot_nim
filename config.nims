from macros import error

const
  nimVersion = (major: NimMajor, minor: NimMinor, patch: NimPatch)

when nimVersion <= (0, 19, 9):
  from ospaths import `/`, splitFile
else:
  from os import `/`, splitFile

const
  doOptimize = true

let
  # sqlite3
  sqliteVersion = getEnv("SQLITEVER", "3400000")
  sqliteSourceDir = "sqlite-autoconf-" & sqliteVersion # sqlite-autoconf-3400000.tar.gz
  sqliteArchiveFile = sqliteSourceDir & ".tar.gz"
  sqliteDownloadLink = "https://www.sqlite.org/2022/" & sqliteArchiveFile
  sqliteInstallDir = (thisDir() / "sqlite/") & sqliteVersion
  sqliteConfigureCmd = ["./configure", "--prefix=" & sqliteInstallDir, "--enable-pcre16", "--enable-pcre32", "--disable-shared"]
  sqliteIncludeDir = sqliteInstallDir / "include"
  sqliteLibDir = sqliteInstallDir / "lib"
  sqliteLibFile = sqliteLibDir / "libsqlite3.a"

  # pcre
  pcreVersion = getEnv("PCREVER", "8.42")
  pcreSourceDir = "pcre-" & pcreVersion
  pcreArchiveFile = pcreSourceDir & ".tar.bz2"
  pcreDownloadLink = "https://downloads.sourceforge.net/pcre/" & pcreArchiveFile
  pcreInstallDir = (thisDir() / "pcre/") & pcreVersion
  # http://www.linuxfromscratch.org/blfs/view/8.1/general/pcre.html
  pcreConfigureCmd = ["./configure", "--prefix=" & pcreInstallDir, "--enable-pcre16", "--enable-pcre32", "--disable-shared"]
  pcreIncludeDir = pcreInstallDir / "include"
  pcreLibDir = pcreInstallDir / "lib"
  pcreLibFile = pcreLibDir / "libpcre.a"

  # libressl
  libreSslVersion = getEnv("LIBRESSLVER", "2.8.1")
  libreSslSourceDir = "libressl-" & libreSslVersion
  libreSslArchiveFile = libreSslSourceDir & ".tar.gz"
  libreSslDownloadLink = "https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/" & libreSslArchiveFile
  libreSslInstallDir = (thisDir() / "libressl/") & libreSslVersion
  libreSslConfigureCmd = ["./configure", "--disable-shared", "--prefix=" & libreSslInstallDir]
  libreSslLibDir = libreSslInstallDir / "lib"
  libreSslLibFile = libreSslLibDir / "libssl.a"
  libreCryptoLibFile = libreSslLibDir / "libcrypto.a"
  libreSslIncludeDir = libreSslInstallDir / "include/openssl"
  # openssl
  openSslSeedConfigOsCompiler = "linux-x86_64"
  openSslVersion = getEnv("OPENSSLVER", "1.1.1")
  openSslSourceDir = "openssl-" & openSslVersion
  openSslArchiveFile = openSslSourceDir & ".tar.gz"
  openSslDownloadLink = "https://www.openssl.org/source/" & openSslArchiveFile
  openSslInstallDir = (thisDir() / "openssl/") & openSslVersion
  # "no-async" is needed for openssl to compile using musl
  #   - https://gitter.im/nim-lang/Nim?at=5bbf75c3ae7be940163cc198
  #   - https://www.openwall.com/lists/musl/2016/02/04/5
  # -DOPENSSL_NO_SECURE_MEMORY is needed to make openssl compile using musl.
  #   - https://github.com/openssl/openssl/issues/7207#issuecomment-420814524
  openSslConfigureCmd = ["./Configure", openSslSeedConfigOsCompiler, "no-shared", "no-zlib", "no-async", "-fPIC", "-DOPENSSL_NO_SECURE_MEMORY", "--prefix=" & openSslInstallDir]
  openSslLibDir = openSslInstallDir / "lib"
  openSslLibFile = openSslLibDir / "libssl.a"
  openCryptoLibFile = openSslLibDir / "libcrypto.a"
  openSslIncludeDir = openSslInstallDir / "include/openssl"

# https://github.com/kaushalmodi/nimy_lisp
proc dollar[T](s: T): string =
  result = $s
proc mapconcat[T](s: openArray[T]; sep = " "; op: proc(x: T): string = dollar): string =
  ## Concatenate elements of ``s`` after applying ``op`` to each element.
  ## Separate each element using ``sep``.
  for i, x in s:
    result.add(op(x))
    if i < s.len-1:
      result.add(sep)

import strutils
import strformat
mode = ScriptMode.Verbose

let sqlite_CFLAGS = [
  # ----- Standard Flags autogen'd by configure. Can be ignored.
  "-DVERSION=\"3.31.1\"",
  "-DSTDC_HEADERS=1",
  "-DHAVE_SYS_TYPES_H=1",
  "-DHAVE_SYS_STAT_H=1",
  "-DHAVE_STDLIB_H=1",
  "-DHAVE_STRING_H=1",
  "-DHAVE_MEMORY_H=1",
  "-DHAVE_STRINGS_H=1",
  "-DHAVE_INTTYPES_H=1",
  "-DHAVE_STDINT_H=1",
  "-DHAVE_UNISTD_H=1",
  "-DHAVE_DLFCN_H=1",
  "-DHAVE_FDATASYNC=1",
  "-DHAVE_USLEEP=1",
  "-DHAVE_LOCALTIME_R=1",
  "-DHAVE_GMTIME_R=1",
  "-DHAVE_DECL_STRERROR_R=1",
  "-DHAVE_STRERROR_R=1",
  "-DHAVE_READLINE_READLINE_H=1",
  "-DHAVE_READLINE=1",
  "-DHAVE_POSIX_FALLOCATE=1",
  "-DHAVE_ZLIB_H=1",
  "-D_REENTRANT=1",
  # ----- Custom flags for sqlite, See the following links:
  #     https://www.sqlite.org/howtocompile.html
  #     https://www.sqlite.org/compile.html
  "-DSQLITE_THREADSAFE=2",              # Multithreaded, but a single db_conn is not thread safe
  "-DSQLITE_OMIT_LOAD_EXTENSION=1",     # Dynamic linking turned off
  "-DSQLITE_DQS=0",                     # Disable double quoted string literal bug
  "-DSQLITE_DEFAULT_MEMSTATUS=0",       # Disable memstatus
  "-DSQLITE_LIKE_DOESNT_MATCH_BLOBS",   # Optimize LIKE queries
  "-DSQLITE_MAX_EXPR_DEPTH=0",          # No limits of expression depth
  "-DSQLITE_OMIT_DECLTYPE",             # Optimize prepared statements
  "-DSQLITE_OMIT_DEPRECATED",           # No legacy code here
  "-DSQLITE_OMIT_PROGRESS_CALLBACK",    # Progress handler not used
  "-DSQLITE_OMIT_SHARED_CACHE",         # No shared cache used
  "-DSQLITE_USE_ALLOCA",                # Alloca is available
  "-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1", # Use WAL mode
  # "-DSQLITE_HAVE_ZLIB",               # Zlib not used
  # "-DSQLITE_ENABLE_FTS4",             # FTS3/4 not used
  # "-DSQLITE_ENABLE_FTS5",             # FTS5 not used
  # "-DSQLITE_ENABLE_JSON1",            # Json not used
  # "-DSQLITE_ENABLE_RTREE",            # Rtree not used
  # "-DSQLITE_ENABLE_GEOPOLY",          # Geopoly not used
  ]

let CC = "gcc"
let OPT = "Os"
let sqlite_cfile = "./sqlite-autoconf-3400000/sqlite3.c"
let sqlite_ofile = "./sqlite-autoconf-3400000/sqlite3.o"

# -------------- TASKS HERE ----------------------

task build_sqlite, "compile sqlite3 using custom options":
  if not fileExists(sqlite_cfile):
    raise newException(OSError, """sqlite3.c not found. 
    Download the sqlite3 file from here: https://www.sqlite.org/download.html"
    Then, run this command. It is not added to this git repo for size reasons""")
  let sqlite_CFLAGS_str = sqlite_CFLAGS.join(" ")
  exec fmt"{CC} -c -o {sqlite_ofile} -{OPT} {sqlite_CFLAGS_str} {sqlite_cfile}"

task static_sqlite, "statically link executable with sqlite3":
  if not fileExists(sqlite_ofile):
    build_sqliteTask()
  let sqlite_LFLAGS = fmt"{sqlite_ofile} -lm -pthread"
  --dynlibOverride: sqlite3
  switch("passL", sqlite_LFLAGS)
  setCommand "c"

task installSqlite, "Installs Sqlite using musl-gcc":
  if not fileExists(sqliteLibFile):
    if not dirExists(sqliteSourceDir):
      if not fileExists(sqliteArchiveFile):
        exec("curl -LO " & sqliteDownloadLink)
      exec("tar xf " & sqliteArchiveFile)
    else:
      echo "Sqlite lib source dir " & sqliteSourceDir & " already exists"
    withDir sqliteSourceDir:
      putEnv("CC", "musl-gcc -static")
      exec(sqliteConfigureCmd.mapconcat())
      exec("make -j8")
      exec("make install")
  else:
    echo sqliteLibFile & " already exists"
  setCommand("nop")

task installPcre, "Installs PCRE using musl-gcc":
  if not fileExists(pcreLibFile):
    if not dirExists(pcreSourceDir):
      if not fileExists(pcreArchiveFile):
        exec("curl -LO " & pcreDownloadLink)
      exec("tar xf " & pcreArchiveFile)
    else:
      echo "PCRE lib source dir " & pcreSourceDir & " already exists"
    withDir pcreSourceDir:
      putEnv("CC", "musl-gcc -static")
      exec(pcreConfigureCmd.mapconcat())
      exec("make -j8")
      exec("make install")
  else:
    echo pcreLibFile & " already exists"
  setCommand("nop")

task installLibreSsl, "Installs LIBRESSL using musl-gcc":
  if (not fileExists(libreSslLibFile)) or (not fileExists(libreCryptoLibFile)):
    if not dirExists(libreSslSourceDir):
      if not fileExists(libreSslArchiveFile):
        exec("curl -LO " & libreSslDownloadLink)
      exec("tar xf " & libreSslArchiveFile)
    else:
      echo "LibreSSL lib source dir " & libreSslSourceDir & " already exists"
    withDir libreSslSourceDir:
      #  -idirafter /usr/include/ # Needed for linux/sysctl.h
      #  -idirafter /usr/include/x86_64-linux-gnu/ # Needed for Travis/Ubuntu build to pass, for asm/types.h
      putEnv("CC", "musl-gcc -static -idirafter /usr/include/ -idirafter /usr/include/x86_64-linux-gnu/")
      putEnv("C_INCLUDE_PATH", libreSslIncludeDir)
      exec(libreSslConfigureCmd.mapconcat())
      exec("make -j8 -C crypto") # build just the "crypto" component
      exec("make -j8 -C ssl")    # build just the "ssl" component
      exec("make -C crypto install")
      exec("make -C ssl install")
  else:
    echo libreSslLibFile & " already exists"
  setCommand("nop")

task installOpenSsl, "Installs OPENSSL using musl-gcc":
  if (not fileExists(openSslLibFile)) or (not fileExists(openCryptoLibFile)):
    if not dirExists(openSslSourceDir):
      if not fileExists(openSslArchiveFile):
        exec("curl -LO " & openSslDownloadLink)
      exec("tar xf " & openSslArchiveFile)
    else:
      echo "OpenSSL lib source dir " & openSslSourceDir & " already exists"
    withDir openSslSourceDir:
      # https://gcc.gnu.org/onlinedocs/gcc/Directory-Options.html
      #  -idirafter /usr/include/ # Needed for Travis/Ubuntu build to pass, for linux/version.h, etc.
      #  -idirafter /usr/include/x86_64-linux-gnu/ # Needed for Travis/Ubuntu build to pass, for asm/types.h
      putEnv("CC", "musl-gcc -static -idirafter /usr/include/ -idirafter /usr/include/x86_64-linux-gnu/")
      putEnv("C_INCLUDE_PATH", openSslIncludeDir)
      exec(openSslConfigureCmd.mapconcat())
      echo "The insecure switch -DOPENSSL_NO_SECURE_MEMORY is needed so that OpenSSL can be compiled using MUSL."
      exec("make -j8 depend")
      exec("make -j8")
      exec("make install_sw")
  else:
    echo openSslLibFile & " already exists"
  setCommand("nop")

# -d:musl
when defined(musl):
  var
    muslGccPath: string
  echo "  [-d:musl] Building a static binary using musl .."
  muslGccPath = findExe("musl-gcc")
  # echo "debug: " & muslGccPath
  if muslGccPath == "":
    error("'musl-gcc' binary was not found in PATH.")
  switch("passL", "-static")
  switch("gcc.exe", muslGccPath)
  switch("gcc.linkerexe", muslGccPath)

  # -d:sqlite3
  when defined(sqlite3):
    if not fileExists(sqliteLibFile):
      selfExec "installSqlite" 
      # selfExec "static_sqlite"
    switch("passC", "-I" & sqliteIncludeDir)
    switch("define", "useSqliteHeader")
    switch("passL", sqliteLibFile)

  # -d:pcre
  when defined(pcre):
    if not fileExists(pcreLibFile):
      selfExec "installPcre"    # Install PCRE in current dir if pcreLibFile is not found
    switch("passC", "-I" & pcreIncludeDir) # So that pcre.h is found when running the musl task
    switch("define", "usePcreHeader")
    switch("passL", pcreLibFile)

  # -d:libressl or -d:openssl
  when defined(libressl) or defined(openssl):
    switch("define", "ssl")     # Pass -d:ssl to nim
    when defined(libressl):
      let
        sslLibFile = libreSslLibFile
        cryptoLibFile = libreCryptoLibFile
        sslIncludeDir = libreSslIncludeDir
        sslLibDir = libreSslLibDir
    when defined(openssl):
      let
        sslLibFile = openSslLibFile
        cryptoLibFile = openCryptoLibFile
        sslIncludeDir = openSslIncludeDir
        sslLibDir = openSslLibDir

    if (not fileExists(sslLibFile)) or (not fileExists(cryptoLibFile)):
      # Install SSL in current dir if sslLibFile or cryptoLibFile is not found
      when defined(libressl):
        selfExec "installLibreSsl"
      when defined(openssl):
        selfExec "installOpenSsl"
    switch("passC", "-I" & sslIncludeDir) # So that ssl.h is found when running the musl task
    switch("passL", "-L" & sslLibDir)
    switch("passL", "-lssl")
    switch("passL", "-lcrypto") # This *has* to come *after* -lssl
    switch("dynlibOverride", "libssl")
    switch("dynlibOverride", "libcrypto")

proc binOptimize(binFile: string) =
  ## Optimize size of the ``binFile`` binary.
  echo ""
  if findExe("strip") != "":
    echo "Running 'strip -s' .."
    exec "strip -s " & binFile
  if findExe("upx") != "":
    # https://github.com/upx/upx/releases/
    echo "Running 'upx --best' .."
    exec "upx --best " & binFile

# nim musl foo.nim
task musl, "Builds an optimized static binary using musl":
  ## Usage: nim musl [-d:pcre] [-d:libressl|-d:openssl] <FILE1> <FILE2> ..
  var
    switches: seq[string]
    nimFiles: seq[string]
  let
    numParams = paramCount()

  when defined(libressl) and defined(openssl):
    error("Define only 'libressl' or 'openssl', not both.")

  # param 0 will always be "nim"
  # param 1 will always be "musl"
  for i in 2 .. numParams:
    if paramStr(i)[0] == '-':    # -d:foo or --define:foo
      switches.add(paramStr(i))
    else:
      # Non-switch parameters are assumed to be Nim file names.
      nimFiles.add(paramStr(i))

  if nimFiles.len == 0:
    error(["The 'musl' sub-command accepts at least one Nim file name",
           "  Examples: nim musl FILE.nim",
           "            nim musl FILE1.nim FILE2.nim",
           "            nim musl -d:pcre FILE.nim",
           "            nim musl -d:libressl FILE.nim",
           "            nim musl -d:libsqlite3 FILE.nim",
           "            nim musl -d:pcre -d:openssl -d:libsqlite3 FILE.nim"].mapconcat("\n"))

  for f in nimFiles:
    let
      extraSwitches = switches.mapconcat()
      (dirName, baseName, _) = splitFile(f)
      binFile = dirName / baseName  # Save the binary in the same dir as the nim file
      nimArgsArray = when doOptimize:
                       ["c", "-d:musl", "-d:release", "--opt:size", extraSwitches, f]
                     else:
                       ["c", "-d:musl", extraSwitches, f]
      nimArgs = nimArgsArray.mapconcat()
    # echo "[debug] f = " & f & ", binFile = " & binFile

    # Build binary
    echo "\nRunning 'nim " & nimArgs & "' .."
    selfExec nimArgs

    when doOptimize:
      # Optimize binary
      binOptimize(binFile)

    echo "\nCreated binary: " & binFile