Path = require("path")
Fs = require("fs")
Utils = require("./utils")
Async = require("async")
Prompt = require("prompt")
Prompt.message = ''
Pg = require("pg.js")


class Postgresql
  constructor: (@config) ->
    @config.host = 'localhost' unless @config.host?
    @config.port = 5432 unless @config.port?
    process.env.PGPASSWORD = @config.password


  using: (config, cb) ->
    if arguments.length == 1
      cb = config
      config = @config
    Pg.connect config, cb


  exec: (sql, cb) ->
    @using (err, client, release) ->
      return cb(err) if err

      client.query sql, (err, result) ->
        release()
        # if err
        #   console.error(err)
        cb err, result


  execFileCLI: (filename, cb) ->
    port = @config.port || 5432
    host = @config.host || "localhost"
    command = "psql"
    #args = ["-U", @config.user, "-a", "-e", "-d", @config.database, "-h", host, "-p", port, "--file=#{filename}", "-1", "--set", "ON_ERROR_STOP=1"]
    args = ["-U", @config.user, "-q", "-d", @config.database, "-h", host, "-p", port, "--file=#{filename}", "-1", "--set", "ON_ERROR_STOP=1"]
    Utils.spawn command, args, {
      cwd: Path.dirname(filename)
      # env:
      #   PGPASSWORD: @config.password
    }, cb


  dbConsoleScript: ->
    port = @config.port || 5432
    host = @config.host || "localhost"
    # TODO need comparable script on Windows
    Fs.writeFileSync "migrations/dbconsole", """#!/bin/sh
PGPASSWORD="#{@config.password}" psql -U #{@config.user} -d #{@config.database} -h #{host} -p #{port}
""", {mode: 0o755}

  "console": ->
    port = @config.port || 5432
    host = @config.host || "localhost"
    command = "psql"
    args = ["-U", @config.user, "-d", @config.database, "-h", host, "-p", port]
    Utils.spawn command, args, {
      stdio: 'inherit'
    }, (code) ->
      process.exit code

  execFile: (args...) ->
    @execFileCLI args...


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
    @exec sql, (err, result) ->
      return cb(err) if err
      cb null, result.rows[0]


  all: (cb) ->
    sql = """
      select *
      from schema_migrations
      order by version desc;
    """
    @exec sql, (err, result) ->
      if err?.message?.indexOf('"schema_migrations" does not exist') > 0
        return cb(null, [])
      return cb(err) if err
      cb null, result.rows


  add: (version, up, down, cb) ->
    sql = """
      insert into schema_migrations(version, up, down)
      values($1, $2, $3)
    """
    @using (err, client) ->
      client.query sql, [version, up, down], cb


  remove: (version, cb) ->
    sql = """
      delete from schema_migrations
      where version = $1
    """
    @using (err, client) ->
      client.query sql, [version], (err) ->
        cb err


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
          "drop database if exists #{config.database};"
          "drop user if exists #{config.user};"
          "create user #{config.user} password '#{config.password}' SUPERUSER CREATEROLE;"
          "create database #{config.database} owner #{config.user};"
      ]

      execRootSql = (sql, cb) ->
        rootConfig =
          user: user
          password: password
          host: config.host
          port: config.port
          database: "postgres"

        using rootConfig, (err, client) ->
          console.error(err) if err
          client.query sql, cb


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
          "drop database if exists #{config.database};"
          "drop user if exists #{config.user};"
      ]

      execRootSql = (sql, cb) ->
        rootConfig =
          user: user
          password: password
          host: config.host
          port: config.port
          database: "postgres"

        using rootConfig, (err, client) ->
          console.error(err) if err
          client.query sql, cb

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

