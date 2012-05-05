_ = require("underscore")
CP = require("child_process")

exports.exec = (command, cb) ->
  console.log command

  CP.exec command, (err, stdout, stderr) ->
    console.log("STDOUT", stdout) unless _.isEmpty(stdout)
    unless _.isEmpty(stderr)
      err = stderr
    cb err
