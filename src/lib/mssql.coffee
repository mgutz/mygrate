Path = require("path")
Fs = require("fs")
Utils = require("./utils")
Async = require("async")
Prompt = require("prompt")
Prompt.message = ''
SqlServer = require('dalicious/dalicious-mssql')
_ = require('lodash')
Async = require('async')

class Mssql
  constructor: (@config) ->
    @config.server = 'localhost' unless @config.server?
    @config.port = 1433 unless @config.port?
    @UserDb = SqlServer.define(@config)

  acquire: ->
    @store ?= new @UserDb()

  _exec: (sql, args) ->
    store = @acquire()
    store.sql sql, args

  exec: (sql, cb) ->
    @_exec(sql).exec cb

  logError: (err) ->
    if err.position
      info = errorToLineCol(script, err)
      console.error "#{Path.basename(filename)} [#{info.line}, #{info.column}] #{info.message}\n"
      return cb(err)

  execFile: (filename, cb) ->
    try
      script = Fs.readFileSync(filename, 'utf8')
    catch err
      return cb(err)

    store = @acquire().transactable()
    Async.series [
      (cb) -> store.begin cb
      (cb) -> store.sql(script).exec cb
    ], (err) ->
      if err
        console.error "ERRRRRRRRRRR", err
        store.rollback -> cb(err)
      else
        store.commit cb

  console: ->
    throw new Error('Console is not implemented as it is not cross-platform')
    port = @config.port || 543

    ###
    exports.up = (H) -> [
      H.createTableNX "schema_migrations(
        version varchar(256) not null primary key,
        up varchar(max),
        down varchar(max),
        created_at datetime default getdate()
      )
      """

      """select * from table"""
    ]

    ###

  init: (cb) ->
    sql = """
      IF NOT EXISTS (SELECT *
         FROM INFORMATION_SCHEMA.TABLES
         WHERE TABLE_SCHEMA = 'dbo'
         AND TABLE_NAME = 'schema_migrations')
      BEGIN
        create table schema_migrations (
          version varchar(256) not null primary key,
          up varchar(max),
          down varchar(max),
          created_at datetime default getdate()
        );
      END
    """
    @exec sql, cb


  last: (cb) ->
    sql = """
      select top 1 *
      from schema_migrations
      order by version desc;
    """
    @_exec(sql).one cb


  all: (cb) ->
    sql = """
      select *
      from schema_migrations
      order by version desc;
    """
    @_exec(sql).all (err, rows) ->
      if err?.message?.indexOf('Invalid object name') >= 0
        return cb(null, [])
      return cb(err) if err
      cb null, rows

  add: (version, up, down, cb) ->
    sql = """
      insert into schema_migrations(version, up, down)
      values($1, $2, $3)
    """
    @_exec(sql, [version, up, down]).exec cb


  remove: (version, cb) ->
    sql = """
      delete from schema_migrations
      where version = $1
    """
    @_exec(sql, [version]).exec cb


  createDatabase: (defaultUser) ->
    config = @config
    sql = """
      IF NOT EXISTS
          (SELECT name
           FROM master.sys.server_principals
           WHERE name = '#{config.user}')
      BEGIN
          CREATE LOGIN [#{config.user}] WITH PASSWORD = N'#{config.password}'
      END
      GO

      IF (EXISTS (
        SELECT name
        FROM master.dbo.sysdatabases
        WHERE ('[' + name + ']' = '#{config.database}'
        OR name = '#{config.database}')
      ))
        drop database [#{config.database}];
      GO

      create database [#{config.database}];
      GO

      USE #{config.database};
      GO
      CREATE USER #{config.user} FOR LOGIN #{config.user};
      exec sp_addrolemember 'db_owner', '#{config.user}';
      GO
    """

    @_execRoot defaultUser, sql, (err) ->
      if (err)
        console.error err
        console.error "Verify migrations/config.js has the correct host and port"
        process.exit 1
      else
        console.log """Created
\tdatabase: #{config.database}
\tuser: #{config.user}
\tpassword: #{config.password}
\tserver: #{config.server}
\tport: #{config.port}
"""
        console.log "OK"
        process.exit 0


  # Creates the deploy specific environemnt database from migrations/config.js
  # using a root user instead of the user defined in config.js.
  #
  # @param {String} deployEnv
  _execRoot: (defaultUser, sql, cb) ->
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

      # TODO same to pssql
      #
      #

      rootConfig = _.defaults({user, password, database: null}, config)
      RootDb = SqlServer.define(rootConfig)
      store = new RootDb()
      store.sql(sql).exec cb


  # Creates the deploy specific environemnt database from migrations/config.js
  # using a root user instead of the user defined in config.js.
  #
  # @param {String} deployEnv
  dropDatabase: (defaultUser) ->
    config = @config
    sql = """
      IF (EXISTS (
        SELECT name
        FROM master.dbo.sysdatabases
        WHERE ('[' + name + ']' = '#{config.database}'
        OR name = '#{config.database}')
      ))
        drop database [#{config.database}];
      GO

      IF EXISTS
          (SELECT name
           FROM master.sys.server_principals
           WHERE name = '#{config.user}')
      BEGIN
          DROP LOGIN [#{config.user}];
      END
    """

    @_execRoot defaultUser, sql, (err) ->
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

module.exports = Mssql

