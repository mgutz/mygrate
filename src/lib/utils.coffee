spawn = require('child_process').spawn

exports.spawn = (command, args, opts, cb) ->
  cmd = spawn(command, args, opts)

  if cmd.stdout
    cmd.stdout.on 'data', (data) ->
      console.log data.toString()

  if cmd.stderr
    cmd.stderr.on 'data', (data) ->
      console.error data.toString()

  cmd.on 'close', (code) ->
    cb code

exports.launch = (command, args, opts) ->
  cmd = spawn(command, args, opts)
  cmd.unref()

