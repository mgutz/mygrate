Path = require("path")
Fs = require("fs")
Utils = require("./utils")
Async = require("async")
Prompt = require("prompt")
Prompt.message = ''
Postgres = require('dalicious/dalicious-postgres')

SqlError = (message, filename, line, column) ->
  this.name = "SqlError"
  this.message = message
  this.filename = filename
  this.line = line
  this.column = column
SqlError.prototype = new Error()
SqlError::constructor = SqlError


###
# Finds the line, col based on error.position
###
toSqlError = (filename, err, sql="") ->
  if not err.position?
    return err.message

  if not sql
    try
      sql = Fs.readFileSync(filename, 'utf8')
    catch err
      return err

  message = err.message
  position = err.position - 1 # postgres 1-based
  line = 1
  column = 1
  max = sql.length

  i = 0
  while i < max and i < position
    ch = sql[i]
    if ch is '\r'
      line++
      column = 1
      # account for windows
      if i+1 < max
        if sql[i+1] is '\n'
          i++
    else if ch is '\n'
      line++
      column = 1
    else
      column++
    i++

  new SqlError(message, filename, line, column)


class Postgresql
  constructor: (@config) ->
    @config.host = 'localhost' unless @config.host?
    @config.port = 5432 unless @config.port?
    @UserDb = Postgres.define(@config)

  exec: (cmd, cb) ->
    @store ?= new @UserDb()
    @store.sql(cmd).exec cb

  logError: (err) ->
    if err.position
      info = errorToLineCol(script, err)
      console.error "#{Path.basename(filename)} [#{info.line}, #{info.column}] #{info.message}\n"
      return cb(err)

  execFileCLI: (filename, cb) ->
    port = @config.port || 5432
    host = @config.host || "localhost"
    command = "psql"
    #args = ["-U", @config.user, "-a", "-e", "-d", @config.database, "-h", host, "-p", port, "--file=#{filename}", "-1", "--set", "ON_ERROR_STOP=1"]
    args = ["-U", @config.user, "-q", "-d", @config.database, "-h", host, "-p", port, "--file=#{filename}", "-1", "--set", "ON_ERROR_STOP=1"]
    Utils.spawn command, args, {
      cwd: Path.dirname(filename)
      env_add:
        PGPASSWORD: @config.password
    }, cb

  execFileDriver: (filename, opts, cb) ->
    tx = null

    if typeof opts == 'function'
      cb = opts
      opts = {}

    try
      script = Fs.readFileSync(filename, 'utf8')
    catch err
      return cb(err)

    if opts.notx
      @store.sql(script).exec (err, result) ->
        if err
          err = toSqlError(filename, err, script)
          console.error err
          return cb(1)
        return cb()
    else
      tx = @store.transactable()
      tx.begin()
      tx.sql(script).exec (err, result) ->
        if err
          err = toSqlError(filename, err, script)
          console.error err
          tx.rollback ->
            return cb(1)
        else
          tx.commit cb

  console: ->
    port = @config.port || 5432
    host = @config.host || "localhost"
    command = "psql"
    args = ["-U", @config.user, "-d", @config.database, "-h", host, "-p", port]
    Utils.spawn command, args, {
      stdio: 'inherit'
      env_add:
        PGPASSWORD: @config.password
    }, (code) ->
      process.exit code


  execFile: (args...) ->
    #@execFileCLI args...
    @execFileDriver args...


  init: (cb) ->
    sql = """
        create table if not exists schema_migrations (
          version varchar(256) not null primary key,
          up text,
          down text,
          created_at timestamp default current_timestamp
        );
      """
    @exec sql, cb


  last: (cb) ->
    sql = """
      select *
      from schema_migrations
      order by version desc
      limit 1;
    """
    @exec sql, (err, rows) ->
      return cb(err) if err
      cb null, rows[0]


  all: (cb) ->
    sql = """
      select *
      from schema_migrations
      order by version desc;
    """
    @exec sql, (err, rows) ->
      if err?.message?.indexOf('"schema_migrations" does not exist') > 0
        return cb(null, [])
      return cb(err) if err
      cb null, rows


  add: (version, up, down, cb) ->
    sql = """
      insert into schema_migrations(version, up, down)
      values($1, $2, $3)
    """
    @store.sql(sql, [version,up,down]).exec cb


  remove: (version, cb) ->
    sql = """
      delete from schema_migrations
      where version = $1
    """
    @store.sql(sql, [version]).exec cb


  # Creates the deploy specific environemnt database from migrations/config.js
  # using a root user instead of the user defined in config.js.
  #
  # @param {String} deployEnv
  createDatabase: (defaultUser) ->
    Prompt.delimiter = ""
    Prompt.start()

    self = @
    config = @config
    using = @using

    prompts = [
      { name: 'user', description: 'root user', default: defaultUser }
      { name: 'password', hidden: true}
      # { name: 'host', default: 'localhost'}
      # { name: 'port', default: '5432'}
    ]

    Prompt.get prompts, (err, result) ->
      {user, password, host, port} = result
      password = null if password.trim().length == 0

      statements = [
          # kill all connections first
          # NOTE: pid is procpid in PostgreSQL < 9.2
          """
            select pg_terminate_backend(pid)
            from pg_stat_activity
            where datname='#{config.database}'
              and pid <> pg_backend_pid()
          """
          "drop database if exists #{config.database};"
          "drop user if exists #{config.user};"
          "create user #{config.user} password '#{config.password}' SUPERUSER CREATEROLE;"
          "create database #{config.database} owner #{config.user};"
      ]

      rootConfig =
        user: user
        password: password
        host: config.host
        port: config.port
        database: "postgres"
      RootDb = Postgres.define(rootConfig)
      store = new RootDb()

      execRootSql = (sql, cb) ->
        console.log 'SQL', sql
        store.sql(sql).exec cb

      Async.forEachSeries statements, execRootSql, (err) ->
        if (err)
          console.error err
          console.error "Verify migrations/config.js has the correct host and port"
          process.exit 1
        else
          console.log """Created
\tdatabase: #{config.database}
\tuser: #{config.user}
\tpassword: #{config.password}
\thost: #{config.host}
\tport: #{config.port}
"""
          console.log "OK"
          process.exit 0

  # Creates the deploy specific environemnt database from migrations/config.js
  # using a root user instead of the user defined in config.js.
  #
  # @param {String} deployEnv
  dropDatabase: (defaultUser) ->
    Prompt.delimiter = ""
    Prompt.start()

    self = @
    config = @config

    prompts = [
      { name: 'user', description: 'root user', default: defaultUser }
      { name: 'password', hidden: true}
      # { name: 'host', default: 'localhost'}
      # { name: 'port', default: '5432'}
    ]

    Prompt.get prompts, (err, result) ->
      {user, password, host, port} = result
      password = null if password.trim().length == 0

      statements = [
          "drop database if exists #{config.database};"
          "drop user if exists #{config.user};"
      ]

      rootConfig =
        user: user
        password: password
        host: config.host
        port: config.port
        database: "postgres"
      RootDb = Postgres.define(rootConfig)
      store = new RootDb()

      execRootSql = (sql, cb) ->
        store.sql(sql).exec cb

      Async.forEachSeries statements, execRootSql, (err) ->
        if (err)
          console.error err
          process.exit 1
        else
          console.log """Dropped
\tdatabase: #{config.database}
\tuser: #{config.user}
"""
          console.log "OK"
          process.exit 0

module.exports = Postgresql

