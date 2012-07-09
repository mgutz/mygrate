mysql = require("mysql")
Utils = require("./utils")
Path = require("path")


class Mysql
  constructor: (@config) ->

  using: (cb) ->
    client = mysql.createClient(user: @config.user, password: @config.password, database: @config.database)
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

module.exports = Mysql
