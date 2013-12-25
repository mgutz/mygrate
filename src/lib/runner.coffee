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
  Usage: mygrate [options] [command]

  Commands:

    createdb      Create database from config.js and $NODE_ENV
    down          Undo {COUNT|VERSION|all} migrations.

        mygrate down 3  # down 3 migrations in DB
        mygrate down 201204261323-people # down including this
        mygrate down all

    file          Execute SQL script in file
    history       Show migrations in database. (default)
    init          Creates migration directory with config

        mygrate init {postgresql|mysql}

    last          Undo last dir if applied and migrate up
    new           Generate new migration directory

        mygrate new add-tags

    up            Execute new migrations.

  Options:

    -h, --help    output usage information
    -V, --version output the version number
"""

if process.argv.length == 2
  commands.history()

else if argv.help
  showUsage()

else if argv.version
  console.log pkg.name + " " + pkg.version

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


