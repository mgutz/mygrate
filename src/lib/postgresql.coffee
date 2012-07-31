Fs = require("fs")
Path = require("path")
Pg = require("pg")
Utils = require("./utils")

class Postgresql
  constructor: (@config) ->
    @config.host = "localhost" unless @config.host
    @config.port = 5432 unless @config.port
    @config.useDriver = false unless @config.useDriver

  using: (cb) ->
    connectionString = "tcp://"
    connectionString += @config.user
    connectionString += ":"+@config.password if @config.password
    connectionString += "@"+@config.host 
    connectionString += ":"+@config.port
    connectionString += "/"+@config.database

    Pg.connect connectionString, cb


  exec: (sql, cb) ->
    @using (err, client) ->
      return cb(err) if err

      client.query sql, ->
        cb.apply null, Array.prototype.slice.apply(arguments)

  execFile: (filename, cb) ->
    if @config.useDriver
      @withDriver filename, cb
    else
      @withPsql filename, cb

  withPsql: (filename, cb) ->
    port = @config.port || 5432
    host = @config.host || "localhost"
    command = "psql"
    args = ["-U", @config.user, "-d", @config.database, "-h", host, "-p", port, "--file=#{filename}"]
    Utils.pushExec command, args, Path.dirname(filename), cb

  withDriver: (filename, cb) ->
    Fs.readFile filename, 'utf8', (err, data) =>
      return cb(err) if err

      @exec data, cb

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

module.exports = Postgresql

