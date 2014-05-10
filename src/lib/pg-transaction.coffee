###
From: https://github.com/goodybag/node-pg-transaction

Module dependencies
###

EventEmitter = require("events").EventEmitter
util = require("util")

Transaction = module.exports = (client) ->
  @client = client
  return this

util.inherits Transaction, EventEmitter

###
Execute a query, re-emit the events that the client is receiving from this
EventEmitter
###
Transaction::query = ->
  self = this
  query = @client.query.apply(@client, arguments)
  callback = query.callback
  unless callback?
    query.on "error", (err) ->
      self.emit "error", err
      return
  query


###
Start a transaction block
@param  {String}   transaction mode [optional] mode of transaction
@param  {Function} callback
###
Transaction::begin = (mode, callback) ->
  if typeof (mode) is "function"
    callback = mode
    mode = null
  begin = "BEGIN"
  begin += " " + mode  if mode
  @query begin, callback


###
Define a new savepoint within the current transaction
@param  {String}   savepoint name of the savepoint
@param  {Function} callback
###
Transaction::savepoint = (savepoint, callback) ->
  @query "SAVEPOINT " + savepoint, callback


###
Destroy a previously defined savepoint
@param  {String}   savepoint name of the savepoint
@param  {Function} callback
###
Transaction::release = (savepoint, callback) ->
  @query "RELEASE SAVEPOINT " + savepoint, callback


###
Commit the current transaction
@param  {Function} callback
###
Transaction::commit = (callback) ->
  self = this
  @query "COMMIT", (err) ->
    return callback(err)  if callback
    self.emit "error", err  if err


###
Abort the current transaction or rollback to a previous savepoint
@param  {String}   savepoint [optional] name of the savepoint to rollback to
@param  {Function} callback
###
Transaction::rollback = (savepoint, callback) ->
  self = this
  if typeof (savepoint) is "function"
    savepoint = null
    callback = savepoint
  query = (if (savepoint?) then "ROLLBACK TO SAVEPOINT " + savepoint else "ROLLBACK")
  @query query, (err) ->
    return callback(err)  if callback
    self.emit "error", err  if err


###
Abort the current transaction
@param  {Function} callback
###
Transaction::abort = (callback) ->
  self = this
  @query "ABORT TRANSACTION", (err) ->
    return callback(err)  if callback
    self.emit "error", err  if err

