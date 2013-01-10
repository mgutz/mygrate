mysql = require("mysql")
Utils = require("./utils")
Path = require("path")

Async = require("async")
Prompt = require("prompt")
Prompt.message = ''

class Mysql
  constructor: (@config) ->

  using: (config, cb) ->
    if arguments.length  == 1
      cb = config
      config = @config

    #client = mysql.createClient(user: @config.user, password: @config.password, database: @config.database)
    client = mysql.createConnection(config)
    client.connect()
    cb null, client


  exec: (sql, cb) ->
    @using (err, client) ->
      return cb(err) if err

      client.query sql, ->
        cb.apply null, Array.prototype.slice.apply(arguments)

  execFile: (filename, cb) ->
    port = @config.port || 3306
    host = @config.host || "localhost"
    command = "mysql"
    args = ["-u#{@config.user}", "-p#{@config.password}", "-D#{@config.database}", "-h#{host}", "-P#{port}", "-e", "source #{filename}"]
    Utils.pushExec command, args, Path.dirname(filename), cb

  init: (cb) ->
    sql = """
        create table if not exists schema_migrations(
          version varchar(128) not null primary key,
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
    @exec sql, (err, results) ->
      return cb(err) if err
      cb null, results[0]


  all: (cb) ->
    sql = """
      select *
      from schema_migrations
      order by version desc;
    """
    @exec sql, (err, results) ->
      return cb(err) if err
      cb null, results


  add: (version, up, down, cb) ->
    sql = """
      insert into schema_migrations(version, up, down)
      values(?, ?, ?)
    """
    @using (err, client) ->
      client.query sql, [version, up, down], cb


  remove: (version, cb) ->
    sql = """
      delete from schema_migrations
      where version = ?
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
      { name: 'user', description: 'root user', default: 'root' }
      { name: 'password', hidden: true}
    ]

    Prompt.get prompts, (err, result) ->
      {user, password} = result

      statements = [
          "flush privileges;"
          "drop database if exists #{config.database};"
          "create user '#{config.user}'@'localhost' identified by '#{config.password}';"
          "create database #{config.database};"
          "grant all privileges on #{config.database}.* to '#{config.user}'@'localhost';"
      ]

      execRootSql = (sql, cb) ->
        rootConfig =
          user: user
          password: password
          host: config.host
          port: config.port

        using rootConfig, (err, client) ->
          client.query sql, cb

      runScripts = ->
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

      # What a pain to drop a user
      execRootSql "SELECT COUNT(*) AS k FROM mysql.user where User = '#{config.user}';", (err, result) ->
        if result[0].k > 0
          execRootSql "DROP USER '#{config.user}'@'localhost';", (err, result) ->
            runScripts()
        else
          runScripts()







module.exports = Mysql
