_ = require("underscore")
CP = require("child_process")

exports.exec = (command, cb) ->
  console.log command
  
  CP.exec command, (err, stdout, stderr) ->
    console.log(stdout) unless _.isEmpty(stdout)
    console.error(stderr) unless _.isEmpty(stderr)
    if err
      console.error "error: ", err
    cb err
