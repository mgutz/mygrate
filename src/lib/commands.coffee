Fs = require("fs")
Path = require("path")
async = require("async")
Utils = require("./utils")
Table = require("cli-table")
Os = require("os")
_ = require("lodash")
Wrench = require("wrench")
str = require('underscore.string')
ProjTemplate = require('uber-ngen')

cwd = process.cwd()

DEFAULT_MINHOOK_DATE = "999999999999"


errHandler = (err) ->
  if err
    console.error(err)
    process.exit 1
  else
    console.log "OK"
    process.exit 0


getDefaultUser = (vendor) ->
  switch vendor
    when 'mysql'
      user = 'root'
    when 'mssql'
      user = 'sa'
    else
      platform = Os.platform()
      if platform.match(/^darwin/)
        user = process.env.USER
      else
        user = 'postgres'
  return user


getEnv = ->
  env = process.env.NODE_ENV || "development"


getEnvConfig = ->
  getConfig()[getEnv()]


getConfig = ->
  jsFile = Path.join(Commands.migrationsDir,  "config.js")
  jsonFile = Path.join(Commands.migrationsDir,  "config.json")

  if Fs.existsSync(jsFile)
    return require(jsFile)
  else if Fs.existsSync(jsonFile)
    return require(jsonFile)
  else
    console.error "Config file migrations/config.{js,json} NOT FOUND"
    process.exit 1

writeConfig = (config) ->
  Fs.writeFileSync Path.join(Commands.migrationsDir, "config.json"), JSON.stringify(config, null, '  ')


dbInterface = ->
  if !Fs.existsSync(Commands.migrationsDir)
    console.error("#{Commands.migrationsBasename} directory not found")
    process.exit 1

  config = getEnvConfig()

  for adapter, v of config
    continue if adapter == "mygrate"
    Adapter = require("./"+adapter)
    break

  return {
    config: config[adapter],
    minHookDate: config.mygrate?.minHookDate ? DEFAULT_MINHOOK_DATE
    schema: new Adapter(config[adapter])
    vendor: adapter
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


initMigrationsDir = (vendor, config) ->
  unless Fs.existsSync(Commands.migrationsDir)
    Fs.mkdirSync(Commands.migrationsDir)

  unless Fs.existsSync(Commands.migrationsDir + "/config.json")
    writeConfig config
    console.log "Created #{vendor} sample configuration. Edit #{Commands.migrationsBasename}/config.json."


getSubDirs = (dirname, cb) ->
  dirname = Path.resolve(dirname)
  dirs =[]
  for file in Fs.readdirSync(dirname)
    continue unless file.match(/^\d{12}/)
    stat = Fs.statSync(dirname+"/"+file)
    if stat.isDirectory()
      dirs.push file if stat.isDirectory()
  cb null, dirs.sort()


migrationFile = (version, which) ->
  Path.resolve(Commands.migrationsDir+"/"+version+"/"+which+".sql")

readMigrationFile = (migration, which) ->
  filename = migrationFile(migration, which)
  if Fs.existsSync(filename)
    Fs.readFileSync filename, "utf8"
  else
    ""

# Executes a down migration for each migration in `migrations`
down = (schema, migrations, cb) ->
  migrate = (version, cb) ->
    filename = migrationFile(version, "down")
    pre = "Down #{Commands.migrationsBasename}/#{version}"
    schema.execFile filename, (err) ->
      return cb("#{pre}\n#{err}") if err

      schema.remove version, (err) ->
        return cb("#{pre}\n#{err}") if err
        console.log "#{pre}"
        cb null

  async.forEachSeries migrations, migrate, cb


forceDown = (schema, version, cb) ->
    filename = migrationFile(version, "down")
    schema.execFile filename, cb


## COMMANDS
Commands =
  migrationsDir: null
  migrationsBasename: null

  setMigrationsDir:(dirname) ->
    Commands.migrationsDir = Path.resolve(dirname)
    Commands.migrationsBasename = Path.basename(Commands.migrationsDir)

  "console": ->
    {schema} = dbInterface()
    schema.console()


  # Generates a migration with optional `suffix`
  #
  # Example
  #   generate 'add-post'   // creates `migrations/TIME-add-post/up.sql`
  #                         // and `migrations/TIME-add-post/down.sql`
  generate: (argv, vendor) =>
    suffix = argv._[1]
    template = argv.template || "default"
    if !vendor
      {vendor} = dbInterface()

    if !Fs.existsSync(Path.resolve(Commands.migrationsBasename))
      console.error "ERROR #{Commands.migrationBasename} directory not found. Try `mygrate init`"
      process.exit 1

    if typeof suffix isnt "string"
      console.error "Migration identifier missing"
      process.exit 1

    ts = timestamp()
    filename = ts
    if typeof suffix is "string"
      filename += "-"+suffix

    path = Commands.migrationsDir +  "/"+filename
    unless Fs.existsSync(path)
      Wrench.copyDirSyncRecursive Path.resolve(__dirname, "../templates/#{vendor}/content/#{template}"), Path.resolve(path)#, forceDelete: true

      # update minHookDate so prehooks will run with this migration
      if template != 'default'
        config = getConfig()
        if config.development.mygrate.minHookDate == DEFAULT_MINHOOK_DATE
          config.development.mygrate.minHookDate = ts
          writeConfig config
      console.log "Migration created: "+path


  # Initializes migrations directory with sample config.js
  init: (argv) =>
    vendor = argv._[1]

    if ['mysql', 'postgresql', 'mssql'].indexOf(vendor) < 0
      vendor = "postgresql"

    name = Path.basename(process.cwd()).replace(/\W/g, "_")

    if Fs.existsSync(Commands.migrationsDir)
      console.error 'Migrations directory exists.'
      return
    t = new ProjTemplate(vendor, {
      templates: Path.join(__dirname, '../templates')
      name: name
    })
    t.init Commands.migrationsDir, (err) ->
      throw err if err
      #initMigrationsDir vendor, config
      # make it appear like mygrate new init
      argv._ = ["new", "init"]
      Commands.generate argv, vendor


  # Runs all `up` migrations not yet executed on the database.
  migrateUp: (argv, cb) =>
    {schema, config, minHookDate} = dbInterface()
    dirs = null
    lastMigration = null

    async.series {
      ensureSchema: (cb) ->
        schema.init cb

      getMigrationDirs: (cb) ->
        getSubDirs Commands.migrationsDir, (err, subdirs) ->
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
            async.series {
              prehook: (cb) ->
                filename = Commands.migrationsDir + "/#{version}/prehook"
                if Fs.existsSync(filename)
                  timestamp = version.slice(0, 12)
                  if minHookDate.slice(0, 12) > timestamp
                    console.log "Skipping #{version}/prehook"
                    return cb()

                  console.log "Running #{version}/prehook"
                  Utils.spawn filename, [], {cwd: Path.dirname(filename)}, cb
                else
                  cb()

              # some migrations need to be run outside of transaction
              notx: (cb) ->
                filename = migrationFile(version, "notx")
                if !Fs.existsSync(filename)
                  return cb()

                schema.execFile filename, {notx: true}, (err) ->
                    return cb(err) if err

                    console.log "NoTx #{Commands.migrationsBasename}/#{version}"
                    return cb()

              upscript: (cb) ->
                filename = migrationFile(version, "up")
                schema.execFile filename, (err) ->
                  return cb("Up #{Commands.migrationsBasename}/#{version}: exit code #{err}") if err

                  up = readMigrationFile(version, "up")
                  down = readMigrationFile(version, "down")
                  schema.add version, up, down, (err) ->
                    return cb(err) if err

                    console.log "Up #{Commands.migrationsBasename}/#{version}"
                    cb null
            }, cb

          async.forEachSeries versions, migrateUp, cb

        else
          msg = "Nothing to run."
          if lastMigration?.version
            msg += " Last migration: #{Commands.migrationsBasename}/"+lastMigration.version
          console.log msg
          cb null
    }, (err) ->
      if err
        console.error err
        process.exit 1
      else
        console.log "OK"
        process.exit 0


  # Migrates down count versions or before a specific version.
  migrateDown: (argv, cb) =>
    {schema} = dbInterface()

    countOrVersion = argv._[1] ? 1

    dirs = null
    lastMigration = null

    async.series {
      getLastMigration: (cb) ->
        schema.last (err, migration) ->
          return cb(err) if err
          lastMigration = migration
          cb err

      getMigrationDirs: (cb) ->
        getSubDirs Commands.migrationsDir, (err, subdirs) ->
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
          else if _.isNumber(countOrVersion)
            count = countOrVersion
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
      return cb(err) if cb?

      if err
        console.error err
        process.exit 1
      else
        console.log "OK"
        process.exit 0


  migrateLast: ->
    {schema} = dbInterface()

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
        async.series {
          migrateDownIfLast: (cb) ->
            if lastMigration.version == _.last(dirs)
              # make it appear this is argv from cli
              Commands.migrateDown {_:["down", 1]}, (err) ->
                return cb(err) if err
                console.log "OK1\n"
                cb()
            else
              cb()

          migrateUp: (cb) ->
            Commands.migrateUp _:["up"], cb
        }, cb

    }, (err) -> # end of async.series
      if err
        console.error err
        process.exit 1
      else
        console.log "OK2"
        process.exit 0


  printConfig: (config) ->
    s = "Connection: "
    s += config.user
    #s += ":"+config.password.replace(/./g, '*') if config.password
    s += "@" + (config.host || config.server)
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
        table = new Table
          head: ["migrated at", "script set"]

          chars: {
            'top': '' , 'top-mid': '' , 'top-left': '' , 'top-right': '',
            'bottom': '' , 'bottom-mid': '' , 'bottom-left': '' , 'bottom-right': '',
            'left': '' , 'left-mid': '' , 'mid': '' , 'mid-mid': ''
            'right': '' , 'right-mid': '' , 'middle': ' '
          }

        for migration in migrations
          at = timestamp(new Date(migration.created_at), "-")
          table.push [at, migration.version]
        console.log ""
        console.log table.toString()
      process.exit 0

  dropDatabase: (argv) ->
    {schema, vendor} = dbInterface()
    schema.dropDatabase getDefaultUser(vendor), argv

  createDatabase: (argv) ->
    {schema, vendor} = dbInterface()
    schema.createDatabase getDefaultUser(vendor), argv

  execSql: (argv) ->
    sql = argv._[1]
    throw new Error('Empty SQL expression') unless sql?.trim().length > 0
    db = dbInterface().schema
    db.exec sql, (err, result) ->
      if err
        throw new Error(err)
      else
        if result
          console.log JSON.stringify(result, null, 2)
        else
          console.log "Empty result"
        process.exit 0


  execFile: (argv) ->
    filename = argv._[1]
    if typeof filename != 'string'
      return errHandler('Filename required')

    filename = Path.resolve(filename)

    {schema} = dbInterface()
    schema.execFile filename, errHandler

  ping: (argv) ->
    sql = "select 1;"
    db = dbInterface().schema
    db.exec sql, (err, result) ->
      if err
        process.exit 1
      else
        process.exit  0

module.exports = Commands
