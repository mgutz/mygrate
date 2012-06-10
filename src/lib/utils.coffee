_ = require("underscore")
CP = require("child_process")

Util  = require('util')
spawn = require('child_process').spawn

exports.exec = (command, cb) ->
  #console.log command
  CP.exec command, (err, stdout, stderr) ->
    console.log("STDOUT", stdout) unless _.isEmpty(stdout)
    unless _.isEmpty(stderr)
      err = stderr
    cb err

exports.pushExec = (command, args, wd, cb) ->
  #console.dir arguments
  if arguments.length is 3
    cb = wd
    wd = null

  if wd
    cwd = process.cwd()
    process.chdir wd

  cmd = spawn(command, args)

  cmd.stdout.on 'data', (data) ->
    console.log data.toString()

  cmd.stderr.on 'data', (data) ->
    console.error data.toString()

  cmd.on 'exit', (code) ->
    process.chdir(cwd) if wd
    cb code
