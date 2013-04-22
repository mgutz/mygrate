Path = require("path")
Fs = require("fs")
Pg = require("pg")
Utils = require("./utils")
Async = require("async")
Commander = require("commander")
Prompt = require("prompt")
Prompt.message = ''


class Postgresql
  constructor: (@config) ->
    @config.host = 'localhost' unless @config.host?
    @config.port = 5432 unless @config.port?

  using: (config, cb) ->
    if arguments.length == 1
      cb = config
      config = @config

    connectionString = "tcp://"
    connectionString += config.user
    connectionString += ":"+config.password if config.password
    connectionString += "@"+config.host
    connectionString += ":"+config.port if config.port
    connectionString += "/"+config.database if config.database

    console.log

    Pg.connect config, cb


  exec: (sql, cb) ->
    @using (err, client, release) ->
      return cb(err) if err

      client.query sql, (err, result) ->
        release()
        if err
          console.error(err)
        cb err, result


  toSingleStatement: (sql) ->
    if sql.match(/^do\s*\$\$/i)
      sql
    else
      # Wrap script in DO to properly handle multiple statements, which
      # works intermittenly. Once a prepared statement is used, multiple
      # statements do not work as expected. By wrapping it in DO, it becomes
      # a single statement.
       """
DO $$
BEGIN
#{sql}
END $$;
"""

  execFileCLI: (filename, cb) ->
    port = @config.port || 5432
    host = @config.host || "localhost"
    command = "psql"
    args = ["-U", @config.user, "-d", @config.database, "-h", host, "-p", port, "--file=#{filename}"]
    Utils.pushExec command, args, Path.dirname(filename), cb


  # Not too confident using the driver for large scripts. The error
  # information returned is not as helpful as returned by the command
  # line utility. The line number is always off. Moreover, to reliably
  # run multiple statements the script must be run within a `DO$$ ... END$$;`
  execFileDriver: (filename, cb) ->
    me = @
    Fs.readFile filename, 'utf8', (err, script) ->

      script = me.toSingleStatement(script)
      return cb(err) if err
      me.exec script, cb


  execFile: (args...) ->
    @execFileCLI args...


  init: (cb) ->
    sql = """
        create table if not exists schema_migrations(
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
  createDatabase: ->
    Prompt.start()

    config = @config
    using = @using

    prompts = [
      { name: 'user', description: 'root user', default: 'postgres' }
      { name: 'password', hidden: true}
      { name: 'host', default: 'localhost'}
      { name: 'port', default: '5432'}
    ]

    Prompt.get prompts, (err, result) ->
      {user, password, host, port} = result
      password = null if password.trim().length == 0

      statements = [
          "drop database if exists #{config.database};"
          "drop user if exists #{config.user};"
          "create user #{config.user} password '#{config.password}';"
          "create database #{config.database} owner #{config.user};"
      ]

      execRootSql = (sql, cb) ->
        rootConfig =
          user: user
          password: password
          host: host
          port: port
          database: "postgres"

        using rootConfig, (err, client) ->
          console.error(err) if err
          client.query sql, cb


      Async.forEachSeries statements, execRootSql, (err) ->
        if (err)
          console.error(err)
          process.exit(1)
        else
          console.log """Created
\tdatabase: #{config.database}
\tuser: #{config.user}
\tpassword: #{config.password}
\thost: #{config.host}
\tport: #{config.port}
"""
          console.log "OK"
          process.exit(0)

module.exports = Postgresql

