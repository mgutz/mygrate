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


pad2 = (num) -> if num < 9 then "0" + num else num

timestamp = (date=new Date(), separator="")->
  [
    date.getUTCFullYear()
    pad2(date.getUTCMonth() + 1)
    pad2(date.getUTCDate())
    pad2(date.getUTCHours())
    pad2(date.getUTCMinutes())
  ].join(separator)


initMigrationsDir = ->
  unless Path.existsSync("./migrations")
    Fs.mkdirSync("./migrations")
    console.log "`migrations` directory created"

  unless Path.existsSync("./migrations/config.js")
    sample = Fs.readFileSync(__dirname+"/../src/test/config.sample", "utf8")
    Fs.writeFileSync "./migrations/config.js", sample
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
  if Path.existsSync(filename)
    Fs.readFileSync filename, "utf8"
  else
    ""


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
Commands =
  # Generates a migration with optional `suffix`
  #
  # Example
  #   generate 'add-post'   // creates `migrations/TIME-add-post/up.sql`
  #                         // and `migrations/TIME-add-post/down.sql`
  generate: (suffix) =>
    if !Path.existsSync(Path.resolve("migrations"))
      console.error "ERROR migrations directory not found. Try `schema init`"
      process.exit()

    if typeof suffix isnt "string"
      console.error "Migration identifier missing"
      process.exit()

    filename = timestamp()
    if typeof suffix is "string"
      filename += "-"+suffix

    path = "./migrations/"+filename
    unless Path.existsSync(path)
      Fs.mkdirSync path
      Fs.writeFileSync path+"/up.sql", ""
      Fs.writeFileSync path+"/down.sql", ""
      console.log "Migration created: "+path


  # Initializes migrations directory with sample config.js
  init: =>
    initMigrationsDir()
    Commands.generate()


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
      getLastMigration: (cb) ->
        schema.last (err, migration) ->
          return cb(err) if err
          lastMigration = migration
          cb err

      getMigrationDirs: (cb) ->
        getSubDirs "migrations", (err, subdirs) ->
          return cb(err) if err
          dirs = subdirs
          cb null

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


  reset: =>
    {schema} = dbInterface()
    schema.reset (err) ->
      if err
        console.error "Reset: "+err
      else
        console.log "Reset OK"
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


module.exports = Commands
