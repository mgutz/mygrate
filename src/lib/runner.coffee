commands = require('../lib/commands')
pkg = require('../package.json')

argv = require("minimist")(process.argv.slice(2), {
  alias:
    exec: "e"
    version: "V"
    help: "h"
    template: "t"
  default:
    directory: "migrations"
})
command = argv._[0]

showUsage = ->
  console.log """
  #{pkg.name} #{pkg.version}

  Usage: #{pkg.name} [options] [command] [FILENAME.sql]

  Commands:

    console         Runs database CLI
    createdb        (Re)Create database from config.js and $NODE_ENV
    down            Undo {COUNT|VERSION|all} migrations.
    dropdb          Drops the database
    file            Execute SQL script in file
    history         Show migrations in database. (default)
    init            Creates migration directory with config
    last            Undo last dir if applied and migrate up
    new             Generate new migration directory
    ping            Pings the database (0 exit code means OK)
    up              Execute new migrations.
    exec            Execute an expression.

  Options:

        --directory use different directory than migrations
        --examples  output examples
    -h, --help      output usage information
    -V, --version   output the version number
"""

showExamples = ->
  console.log """
  #{pkg.name} #{pkg.version}

  Examples:

    # start database CLI utility
    mygrate console

    # undo last 3 applied migrations in the database
    mygrate down 3

    # undo down all applied migrations including this one
    mygrate down 201204261323-people

    # undo all (`mygrate createdb` is faster)
    mygrate down all

    # create migrations dir and mysql config
    mygrate init mysql

    # create migrations dir and postgresql config
    mygrate init postgresql

    # generate a new migration named migrations/NOW-add-tags
    mygrate new add-tags

    # generate a new migration using plv8 template
    mygrate new add-tags -t plv8

    # run specific file, must end with .sql
    mygrate migrations/test.sql

    # run any other file not having .sql extension
    mygrate file mygrations/test
"""

commands.setMigrationsDir argv.directory

if process.argv.length == 2
  commands.history()

else if argv.help
  showUsage()

else if argv.version
  console.log pkg.name + " " + pkg.version

else if argv.examples
  showExamples()

else if command?.match(/\.sql$/)
  commands.execFile {_: ["file", command]}

else if command
  commands =
    console: commands.console
    createdb: commands.createDatabase
    down: commands.migrateDown
    dropdb: commands.dropDatabase
    file: commands.execFile
    history: commands.history
    last: commands.migrateLast
    init: commands.init
    "new": commands.generate
    ping: commands.ping
    up: commands.migrateUp
    exec: commands.execSql

  fn = commands[command]
  if fn
    fn argv
  else
    showUsage()
else
  showUsage()

# vim: set filetype=javascript:


