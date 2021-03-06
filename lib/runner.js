// Generated by CoffeeScript 1.7.1
(function() {
  var argv, command, commands, fn, pkg, showExamples, showUsage;

  commands = require('../lib/commands');

  pkg = require('../package.json');

  argv = require("minimist")(process.argv.slice(2), {
    alias: {
      exec: "e",
      version: "V",
      help: "h",
      template: "t"
    },
    "default": {
      directory: "migrations"
    }
  });

  command = argv._[0];

  showUsage = function() {
    return console.log("" + pkg.name + " " + pkg.version + "\n\nUsage: " + pkg.name + " [options] [command] [FILENAME.sql]\n\nCommands:\n\n  console         Runs database CLI\n  createdb        (Re)Create database from config.js and $NODE_ENV\n  down            Undo {COUNT|VERSION|all} migrations.\n  dropdb          Drops the database\n  file            Execute SQL script in file\n  history         Show migrations in database. (default)\n  init            Creates migration directory with config\n  redo            Undo last dir if applied and migrate up\n  new             Generate new migration directory\n  ping            Pings the database (0 exit code means OK)\n  up              Execute new migrations.\n  exec            Execute an expression.\n\nOptions:\n\n      --directory use different directory than migrations\n      --examples  output examples\n  -h, --help      output usage information\n  -V, --version   output the version number");
  };

  showExamples = function() {
    return console.log("" + pkg.name + " " + pkg.version + "\n\nExamples:\n\n  # start database CLI utility\n  mygrate console\n\n  # undo last 3 applied migrations in the database\n  mygrate down 3\n\n  # undo down all applied migrations including this one\n  mygrate down 201204261323-people\n\n  # undo all (`mygrate createdb` is faster)\n  mygrate down all\n\n  # create migrations dir and mysql config\n  mygrate init mysql\n\n  # create migrations dir and postgresql config\n  mygrate init postgresql\n\n  # generate a new migration named migrations/NOW-add-tags\n  mygrate new add-tags\n\n  # generate a new migration using plv8 template\n  mygrate new add-tags -t plv8\n\n  # run specific file, must end with .sql\n  mygrate migrations/test.sql\n\n  # run any other file not having .sql extension\n  mygrate file mygrations/test");
  };

  commands.setMigrationsDir(argv.directory);

  if (process.argv.length === 2) {
    commands.history();
  } else if (argv.help) {
    showUsage();
  } else if (argv.version) {
    console.log(pkg.name + " " + pkg.version);
  } else if (argv.examples) {
    showExamples();
  } else if (command != null ? command.match(/\.sql$/) : void 0) {
    commands.execFile({
      _: ["file", command]
    });
  } else if (command) {
    commands = {
      console: commands.console,
      createdb: commands.createDatabase,
      down: commands.migrateDown,
      dropdb: commands.dropDatabase,
      file: commands.execFile,
      history: commands.history,
      redo: commands.migrateLast,
      init: commands.init,
      "new": commands.generate,
      ping: commands.ping,
      up: commands.migrateUp,
      exec: commands.execSql,
      e: commands.execSql
    };
    fn = commands[command];
    if (fn) {
      fn(argv);
    } else {
      showUsage();
    }
  } else {
    showUsage();
  }

}).call(this);
