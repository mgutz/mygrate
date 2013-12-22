spawn = require('child_process').spawn

exports.spawn = (command, args, opts, cb) ->
  cmd = spawn(command, args, opts)

  cmd.stdout.on 'data', (data) ->
    console.log data.toString()

  cmd.stderr.on 'data', (data) ->
    console.error data.toString()

  cmd.on 'close', (code) ->
    cb code
