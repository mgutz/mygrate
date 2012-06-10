Fs = require("fs")
Path = require("path")
prog = require("commander")
async = require("async")

cwd = process.cwd()

dbInterface = ->
  if !Path.existsSync("migrations")
    console.error("migrations directory not found")
    process.exit 1

  env = process.env.NODE_ENV || "development"
  config = require(process.cwd()+"/migrations/config")[env]

  for k, v of config
    adapter = k
    Adapter = require("./"+adapter)
    break


  return {
    connectionInfo: config[adapter],
    schema: new Adapter(config[adapter])
  }


pad2 = (num) -> if num < 9 then "0" + num else num

timestamp = (date=new Date(), separator="") ->
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

  unless Path.existsSync("./migrations/config.js")
    sample = Fs.readFileSync(__dirname+"/../src/test/config.sample", "utf8")
    Fs.writeFileSync "./migrations/config.js", sample
    console.log "Created sample configuration. Edit migrations/config.js."


getSubDirs = (dirname, cb) ->
  dirname = Path.resolve(dirname)
  dirs =[]
  fifiles = Fs.readdirSync(dirname)
  for file in Fs.readdirSync(dirname)
    stat = Fs.statSync(dirname+"/"+file)
    dirs.push file if stat.isDirectory()
  cb null, dirs


migrationFile = (version, which) ->
  Path.resolve("migrations/"+version+"/"+which+".sql")

readMigrationFile = (migration, which) ->
  filename = migrationFile(migration, which)
  if Path.existsSync(filename)
    Fs.readFileSync filename, "utf8"
  else
    ""

# Executes a down migration for each migration in `migrations`
down = (schema, migrations, cb) ->
  migrate = (version, cb) ->
    filename = migrationFile(version, "down")
    schema.execFile filename, (err) ->
      return cb("Down migrations/#{version}: #{err}") if err

      schema.remove version, (err) ->
        return cb("Down migrations/#{version}: #{err}") if err
        console.log "Down migrations/#{version}"
        cb null

  async.forEachSeries migrations, migrate, cb


## COMMANDS
Commands =
  # Generates a migration with optional `suffix`
  #
  # Example
  #   generate 'add-post'   // creates `migrations/TIME-add-post/up.sql`
  #                         // and `migrations/TIME-add-post/down.sql`
  generate: (suffix, options) =>
    if !Path.existsSync(Path.resolve("migrations"))
      console.error "ERROR migrations directory not found. Try `schema init`"
      process.exit 1

    if typeof suffix isnt "string"
      console.error "Migration identifier missing"
      process.exit 1

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
    Commands.generate("init")


  # Runs all `up` migrations not yet executed on the database.
  migrateUp: =>
    {schema} = dbInterface()
    dirs = null
    lastMigration = null

    async.series {
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
          migrateUp = (version, cb) ->
            filename = migrationFile(version, "up")
            schema.execFile filename, (err) ->
              return cb("Up migrations/#{version}: #{err}") if err

              up = readMigrationFile(version, "up")
              down = readMigrationFile(version, "down")
              schema.add version, up, down, (err) ->
                return cb(err) if err

                console.log "Up migrations/#{version}"
                cb null

          async.forEachSeries versions, migrateUp, cb

        else
          msg = "Nothing to run."
          if lastMigration?.version
            msg += " Last recorded migration: migrations/"+lastMigration.version
          console.log msg
          cb null
    }, (err) ->
      if err
        console.error err
        process.exit 1
      else
        console.log "OK"
        process.exit()


  # Migrates down count versions or before a specific version.
  migrateDown: (countOrVersion) =>
    {schema} = dbInterface()

    if typeof countOrVersion isnt "string"
      countOrVersion = "1"

    dirs = null
    lastMigration = null

    async.series {
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
          if migrations.length is 0
            console.log "0 migrations found"
            return cb(null)

          versions = []

          # Undo all
          if countOrVersion is "all"
            for migration in migrations
              versions.push migration.version
            down schema, versions, cb

          # Undo specific count
          else if countOrVersion.length < 3
            count = parseInt(countOrVersion)
            for migration in migrations
              versions.push migration.version
              count -= 1
              break if count is 0

            down schema, versions, cb

          # Undo all migrations including desired version
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
    }, (err) -> # end of async.series
      if err
        console.error err
        process.exit 1
      else
        console.log "OK"
        process.exit()


  # List a history of all executed migrations.
  history: =>
    {connectionInfo, schema} = dbInterface()
    schema.all (err, migrations) ->
      if err
        console.error err
        process.exit 1
      console.log "History connection="+JSON.stringify(connectionInfo)
      if migrations.length < 1
        console.log "0 migrations found"
      else
        for migration in migrations
          at = timestamp(new Date(migration.created_at), "-")
          console.log "#{at}\t#{migration.version}"
      process.exit()


module.exports = Commands
