commands = require('../lib/commands')
pkg = require('../package.json')

argv = require("minimist")(process.argv.slice(2), {
  alias:
    version: "V"
    help: "h"
})
command = argv._[0]

showUsage = ->
  console.log """
  #{pkg.name} #{pkg.version}

  Usage: #{pkg.name} [options] [command] [FILENAME.sql]

  Commands:

    createdb      Create database from config.js and $NODE_ENV
    down          Undo {COUNT|VERSION|all} migrations.
    file          Execute SQL script in file
    history       Show migrations in database. (default)
    init          Creates migration directory with config
    last          Undo last dir if applied and migrate up
    new           Generate new migration directory
    up            Execute new migrations.

  Options:

    -h, --help    output usage information
    -V, --version output the version number

  Examples:

    # undo last 3 applied migrations in the database
    mygrate down 3  # down 3 migrations in DB

    # undo down all applied migrations including this one
    mygrate down 201204261323-people

    # undo all (faster to do `mygrate createdb`)
    mygrate down all

    # create migrations dir and mysql config
    mygrate init mysql

    # create migrations dir and postgresql config
    mygrate init postgresql

    # generate a new migration named migrations/NOW-add-tags
    mygrate new add-tags

    # run specific file, must end with .sql
    mygrate migrations/test.sql

    # run any other psql compatible-file
    mygrate file mygrations/test
"""

if process.argv.length == 2
  commands.history()

else if argv.help
  showUsage()

else if argv.version
  console.log pkg.name + " " + pkg.version

else if command.match(/\.sql$/)
  commands.execFile {_: ["file", command]}

else if command
  commands =
    console: commands.console
    createdb: commands.createDatabase
    down: commands.migrateDown
    file: commands.execFile
    history: commands.history
    last: commands.migrateLast
    init: commands.init
    "new": commands.generate
    "up": commands.migrateUp

  fn = commands[command]
  if fn
    fn(argv)
  else
    showUsage()
else
  showUsage()

# vim: set filetype=javascript:


