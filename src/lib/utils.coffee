spawn = require('child_process').spawn
pty = require("pty.js")

exports.spawn = (command, args, opts, cb) ->
  cmd = spawn(command, args, opts)

  cmd.stdout.on 'data', (data) ->
    console.log data.toString()

  cmd.stderr.on 'data', (data) ->
    console.error data.toString()

  cmd.on 'close', (code) ->
    cb code

exports.launch = (command, args, opts) ->
  cmd = spawn(command, args, opts)
  cmd.unref()



exports.ptyspawn = (command, args, opts, cb) ->
  cmd = pty.spawn(command, args, opts)
  cb()

