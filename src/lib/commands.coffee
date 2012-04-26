Fs = require("fs")
Path = require("path")
prog = require("commander")
async = require("async")

dbInterface = ->
  Postgresql = require("./postgresql")
  env = process.env.NODE_ENV || "development"
  config = require(process.cwd()+"/migrations/config")[env]

  return {
    connectionInfo: config.postgresql,
    schema: new Postgresql(config.postgresql)
  }



pad2 = (num) ->
  out = ""
  out += "0"  if num < 9
  out + num


timestamp = (date=new Date(), separator=" ")->
  [
    date.getUTCFullYear()
    pad2(date.getUTCMonth() + 1)
    pad2(date.getUTCDate())
    pad2(date.getUTCHours())
    pad2(date.getUTCMinutes())
  ].join(separator)


ensureDirs = ->
  unless Path.existsSync("./migrations")
    Fs.mkdirSync("./migrations")
    console.log "`migrations` directory created"

  unless Path.existsSync("./migrations/config.js")
    Fs.writeFileSync "./migrations/config.js", """
module.exports = {
  development: {
    postgresql: "tcp://USER:PASSWORD@HOST/DB"
  },
  test: {
    postgresql: "tcp://USER:PASSWORD@HOST/DB"
  },
  production: {
    postgresql: "tcp://USER:PASSWORD@HOST/DB"
  },
};
"""
    console.log "`migrations/config.js` created. Requires editing."


getSubDirs = (dirname, cb) ->
  dirname = Path.resolve(dirname)
  dirs =[]
  fifiles = Fs.readdirSync(dirname)
  for file in Fs.readdirSync(dirname)
    stat = Fs.statSync(dirname+"/"+file)
    dirs.push file if stat.isDirectory()
  cb null, dirs



readMigrationFile = (migration, which) ->
  filename = "migrations/"+migration+"/"+which+".sql"
  Fs.readFileSync filename, "utf8"


down = (schema, migrations, cb) ->
  async.forEachSeries migrations, (version, cb) ->
    down = readMigrationFile(version, "down")

    schema.exec down, (err) ->
      return cb("Down `migrations/#{version}`: #{err}") if err

      schema.remove version, (err) ->
        return cb("Down `migrations/#{version}`: #{err}") if err
        console.log "Down `migrations/#{version}` OK"
        cb null
  , cb


## COMMANDS
module.exports =
  # Generates a migration with optional `suffix`
  #
  # Example
  #   generate 'add-post'   // creates `migrations/TIME-add-post/up.sql`
  #                         // and `migrations/TIME-add-post/down.sql`
  generate: (suffix) =>
    ensureDirs()

    filename = timestamp()
    if typeof suffix is "string"
      filename += "-"+suffix

    path = "./migrations/"+filename
    unless Path.existsSync(path)
      Fs.mkdirSync path
      Fs.writeFileSync path+"/up.sql", ""
      Fs.writeFileSync path+"/down.sql", ""
      console.log "Migration files created: "+path


  # Runs all `up` migrations not yet executed on the database.
  migrateUp: =>
    {schema} = dbInterface()
    dirs = null
    lastMigration = null

    async.series
      ensureSchema: (cb) ->
        schema.init cb

      getMigrationDirs: (cb) ->
        getSubDirs "migrations", (err, subdirs) ->
          return cb(err) if err
          dirs = subdirs.sort()
          cb null

      getLastMigration: (cb) ->
        schema.last (err, migration) ->
          lastMigration = migration
          cb err

      run: (cb) ->
        if lastMigration?.version
          index = dirs.indexOf(lastMigration.version)
          versions = dirs.slice(index+1)
        else
          versions = dirs

        if versions.length > 0
          async.forEachSeries versions, (version, cb) ->
            up = readMigrationFile(version, "up")
            down = readMigrationFile(version, "down")
            schema.add version, up, down, (err) ->
              return cb(err) if err
              schema.exec up, (err) ->
                if err
                  cb "Up `migrations/#{version}`: #{err}"
                else
                  console.log "Up `migrations/#{version}` OK"
                  cb null
          , cb
        else
          msg = "Nothing to run."
          if lastMigration?.version
            msg += " Last recorded migration: migrations/"+lastMigration.version
          console.log msg
          cb null

    , (err) ->
      if err
        console.error err
      process.exit()


  # Migrates down count versions or before a specific version.
  migrateDown: (countOrVersion) =>
    {schema} = dbInterface()

    if typeof countOrVersion isnt "string"
      countOrVersion = "1"

    dirs = null
    lastMigration = null

    async.series

      getMigrationDirs: (cb) ->
        getSubDirs "migrations", (err, subdirs) ->
          return cb(err) if err
          dirs = subdirs
          cb null

      getLastMigration: (cb) ->
        schema.last (err, migration) ->
          return cb(err) if err
          lastMigration = migration
          cb err

      run: (cb) ->
        schema.all (err, migrations) ->
          return cb(err) if err
          versions = []

          if countOrVersion.length < 3
            count = parseInt(countOrVersion)
            for migration in migrations
              versions.push migration.version
              count -= 1
              break if count is 0

            down schema, versions, cb

          else
            version = countOrVersion

            # collect all versions including desired version
            versions = []
            for migration in migrations
              versions.push migration.version
              if migration.version is version
                found = migration
                break

            if found
              down schema, versions, cb
            else
              cb null


    , (err) ->
      if err
        console.error err
      process.exit()


  # List a history of all executed migrations.
  history: =>
    {connectionInfo, schema} = dbInterface()
    schema.all (err, migrations) ->
      return cb(err) if err
      console.log "History connection="+JSON.stringify(connectionInfo)
      for migration in migrations
        at = timestamp(new Date(migration.created_at), "-")
        console.log "#{at}\t#{migration.version}"
      process.exit()

