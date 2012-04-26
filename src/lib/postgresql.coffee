Pg = require("pg")

class Postgresql
  constructor: (@config) ->

  using: (cb) ->
    Pg.connect @config.connectionString, cb


  exec: (sql, cb) ->
    @using (err, client) ->
      return cb(err) if err

      client.query sql, ->
        cb.apply null, Array.prototype.slice.apply(arguments)


  init: (cb) ->
    sql = """
        create table if not exists schema_migrations(
          version varchar primary key,
          up text ,
          down text,
          created_at timestamp default now()
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

