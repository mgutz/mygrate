Fs = require("fs")
Path = require("path")
async = require("async")
Utils = require("./utils")
Table = require("cli-table")
Os = require("os")
_ = require("underscore")

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

  for adapter, v of config
    continue if adapter == "mygrate"
    Adapter = require("./"+adapter)
    break

  return {
    config: config[adapter],
    minHookDate: config.mygrate?.minHookDate ? "999999999999"
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


initMigrationsDir = (vendor, config) ->
  unless existsSync("./migrations")
    Fs.mkdirSync("./migrations")

  unless existsSync("./migrations/config.js")
    Fs.writeFileSync "./migrations/config.js", config
    console.log "Created #{vendor} sample configuration. Edit migrations/config.js."


getSubDirs = (dirname, cb) ->
  dirname = Path.resolve(dirname)
  dirs =[]
  for file in Fs.readdirSync(dirname)
    stat = Fs.statSync(dirname+"/"+file)
    dirs.push file if stat.isDirectory()
  cb null, dirs.sort()


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

  "console": ->
    {schema} = dbInterface()
    schema.console()


  # Generates a migration with optional `suffix`
  #
  # Example
  #   generate 'add-post'   // creates `migrations/TIME-add-post/up.sql`
  #                         // and `migrations/TIME-add-post/down.sql`
  generate: (argv) =>
    suffix = argv._[1]

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
  init: (argv) =>
    vendor = argv._[1]
    if ['mysql', 'postgresql'].indexOf(vendor) < 0
      vendor = "postgresql"

    name = Path.basename(process.cwd()).replace(/\W/g, "_")

    switch vendor
      when 'mysql'
        config =  """
module.exports = {
  development: {
    mysql: {
      host: "localhost",
      database: "#{name}_dev",
      user: "#{name}_dev_user",
      password: "dev",
      port: 3306
    }
  },
  test: {
    mysql: {
      host: "localhost",
      database: "#{name}_test",
      user: "#{name}_test_user",
      password: "test",
      port: 3306
    }
  },
  production: {
    mysql: {
      host: "localhost",
      database: "#{name}_prod",
      user: "#{name}_prod_user",
      password: "prod",
      port: 3306
    }
  }
};
        """

      when 'postgres', 'postgresql'
        config = """
module.exports = {
  development: {
    postgresql: {
      host: "localhost",
      database: "#{name}_dev",
      user: "#{name}_dev_user",
      password: "dev"
    }
  },
  test: {
    postgresql: {
      host: "localhost",
      database: "#{name}_test",
      user: "#{name}_test_user",
      password: "test"
    }
  },
  production: {
    postgresql: {
      host: "localhost",
      database: "#{name}_prod",
      user: "#{name}_prod_user",
      password: "prod"
    }
  }
};

"""

    initMigrationsDir vendor, config
    # make it appear like mygrate new init
    Commands.generate {_: ["new", "init"]}


  # Runs all `up` migrations not yet executed on the database.
  migrateUp: (argv, cb) =>
    {schema, config, minHookDate} = dbInterface()
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
            async.series {
              prehook: (cb) ->
                filename = Path.resolve("migrations/#{version}/prehook")
                if existsSync(filename)
                  timestamp = version.slice(0, 12)
                  if minHookDate > timestamp
                    console.log "Skipping #{version}/prehook"
                    return cb()

                  console.log "Running #{version}/prehook"
                  Utils.spawn filename, [], {cwd: Path.dirname(filename)}, cb
                else
                  cb()

              upscript: (cb) ->
                filename = migrationFile(version, "up")
                schema.execFile filename, (err) ->
                  return cb("Up migrations/#{version}: exit code #{err}") if err

                  up = readMigrationFile(version, "up")
                  down = readMigrationFile(version, "down")
                  schema.add version, up, down, (err) ->
                    return cb(err) if err

                    console.log "Up migrations/#{version}"
                    cb null
            }, cb

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
        process.exit()


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
        async.series
          migrateDownIfLast: (cb) ->
            if lastMigration.version == _.last(dirs)
              # make it appear this is argv from cli
              Commands.migrateDown {_:["down", 1]}, (err) ->
                return cb(err) if err
                console.log "OK\n"
                cb()
            else
              cb()

          migrateUp: (cb) ->
            Commands.migrateUp()
            cb()
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
        console.log(table.toString())
      process.exit()


  createDatabase: =>
    {schema} = dbInterface()
    platform = Os.platform()
    if platform.match(/^darwin/)
      defaultUser = process.env.USER
    else
      defaultUser = 'postgres'

    schema.createDatabase defaultUser


  execFile: (argv) =>
    filename = argv._[1]
    if typeof filename != 'string'
      return errHandler('Filename required')

    filename = Path.resolve(filename)

    {schema} = dbInterface()
    schema.execFile filename, errHandler

module.exports = Commands
