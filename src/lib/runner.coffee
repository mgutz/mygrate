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
        # rollback 3 migrations
        mygrate down 3
        # rollback before specified version
        mygrate down 201204261323-people
        # rollback all
        mygrate down all

    file          Execute SQL script in file

    history       Show deployed migrations

    init          Creates migration directory with skeleton config.
        mygrate init {postgresql|mysql}

    new           Generate new migration.
        #creates migrations/TIMESTAMP-add-tags/{down,up}.sql
        mygrate new add-tags

    up [options]  Execute new migrations.

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


