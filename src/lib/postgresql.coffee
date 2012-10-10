Path = require("path")
Fs = require("fs")
Pg = require("pg")
Utils = require("./utils")
async = require("async")
Commander = require("commander")

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

    Pg.connect connectionString, (err, client) ->
      if (err)
        console.error err
      cb err, client


  exec: (sql, cb) ->
    @using (err, client) ->
      return cb(err) if err

      client.query sql, cb


  execFile: (filename, cb) ->
    me = @
    Fs.readFile filename, (err, script) ->
      # Wrap script in DO to properly handle multiple statements, which
      # works intermittenly. Once a prepared statement is used, multiple
      # statements do not work as expected. By wrapping it in DO, it becomes
      # a single statement.
      script = """
DO $$
BEGIN
#{script}
END $$;
"""
      return cb(err) if err
      me.exec script, cb


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
    config = @config
    using = @using

    Commander.prompt 'root user (postgres): ', (user='postgres') ->
      Commander.password 'password: ', (password) ->
        process.stdin.destroy()

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
            host: config.host
            port: config.port
            database: "postgres"

          using rootConfig, (err, client) ->
            client.query sql, cb


        async.forEachSeries statements, execRootSql, (err) ->
          if (err)
            console.error(err)
            process.exit(1)
          else
            console.log """Created
    database: #{config.database}
    user: #{config.user}
    password: #{config.password}
    host: #{config.host}
    port: #{config.port}
  """
            console.log "OK"
            process.exit(0)

module.exports = Postgresql

