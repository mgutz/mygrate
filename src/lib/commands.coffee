Fs = require("fs")
Path = require("path")
prog = require("commander")
async = require("async")

existsSync = if Fs.existsSync then Fs.existsSync else Path.existsSync

cwd = process.cwd()


errHandler = (err) ->
  if err
    console.error(err)
  else
    console.log "OK"
    process.exit(1)

dbInterface = ->
  if !existsSync("migrations")
    console.error("migrations directory not found")
    process.exit 1

  env = process.env.NODE_ENV || "development"
  config = require(process.cwd()+"/migrations/config")[env]

  for k, v of config
    adapter = k
    Adapter = require("./"+adapter)
    break


  return {
    config: config[adapter],
    schema: new Adapter(config[adapter])
  }


pad2 = (num) -> if num < 10 then "0" + num else num

timestamp = (date=new Date(), separator="") ->
  [
    date.getUTCFullYear()
    pad2(date.getUTCMonth() + 1)
    pad2(date.getUTCDate())
    pad2(date.getUTCHours())
    pad2(date.getUTCMinutes())
  ].join(separator)


initMigrationsDir = (dbMake) ->
  unless existsSync("./migrations")
    Fs.mkdirSync("./migrations")

  unless existsSync("./migrations/config.js")
    absPath = Path.resolve(__dirname+"/../examples/#{dbMake}/migrations/config.js")
    sample = Fs.readFileSync(absPath, "utf8")
    Fs.writeFileSync "./migrations/config.js", sample
    console.log "Created #{dbMake} sample configuration. Edit migrations/config.js."


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
  if existsSync(filename)
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


forceDown = (schema, version, cb) ->
    filename = migrationFile(version, "down")
    schema.execFile filename, cb


## COMMANDS
Commands =
  # Generates a migration with optional `suffix`
  #
  # Example
  #   generate 'add-post'   // creates `migrations/TIME-add-post/up.sql`
  #                         // and `migrations/TIME-add-post/down.sql`
  generate: (suffix, options) =>
    if !existsSync(Path.resolve("migrations"))
      console.error "ERROR migrations directory not found. Try `mygrate init`"
      process.exit 1

    if typeof suffix isnt "string"
      console.error "Migration identifier missing"
      process.exit 1

    filename = timestamp()
    if typeof suffix is "string"
      filename += "-"+suffix

    path = "./migrations/"+filename
    unless existsSync(path)
      Fs.mkdirSync path
      Fs.writeFileSync path+"/up.sql", ""
      Fs.writeFileSync path+"/down.sql", ""
      console.log "Migration created: "+path


  # Initializes migrations directory with sample config.js
  init: (dbMake) =>
    if typeof dbMake != 'string'
      dbMake = "postgresql"

    if ['mysql', 'postgresql'].indexOf(dbMake) < 0
      dbMake = "postgresql"

    initMigrationsDir dbMake
    Commands.generate "init"


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
              return cb("Up migrations/#{version}: exit code #{err}") if err

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
        # try to save error file for `down` command
        errFile = err.toString().match(/migrations\/([^:]+):/)
        if errFile
          errFile = errFile[1]
          Fs.writeFileSync("migrations/errfile", errFile)
        console.error err
        process.exit 1
      else
        Fs.unlinkSync("migrations/errfile") if existsSync("migrations/errfile")
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

          if countOrVersion == "1"
            if existsSync("migrations/errfile")
              version = Fs.readFileSync("migrations/errfile", "utf8")
              console.log "Trying to recover from #{version} error"
              return forceDown schema, version, (err) ->
                if !err
                  Fs.unlinkSync("migrations/errfile")
                return cb(err)


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

  printConfig: (config) ->
    s = "Connection: "
    s += config.user
    #s += ":"+config.password.replace(/./g, '*') if config.password
    s += "@"+config.host
    s += ":"+config.port if config.port
    s += "/"+config.database if config.database
    console.log s



  # List a history of all executed migrations.
  history: =>
    {config, schema} = dbInterface()
    schema.all (err, migrations) ->
      if err
        console.error err
        process.exit 1
      #console.log "ConnectionHistory connection="+JSON.stringify(connectionInfo)
      Commands.printConfig config
      if migrations.length < 1
        console.log "0 migrations found"
      else
        for migration in migrations
          at = timestamp(new Date(migration.created_at), "-")
          console.log "#{at}\t#{migration.version}"
      process.exit()


  createDatabase: =>
    {schema} = dbInterface()
    schema.createDatabase()


  execFile: (filename) =>
    if typeof filename != 'string'
      return errHandler('Filename required')

    filename = Path.resolve(filename)

    {schema} = dbInterface()
    schema.execFile filename, errHandler

module.exports = Commands
