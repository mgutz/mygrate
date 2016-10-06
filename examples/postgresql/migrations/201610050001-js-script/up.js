'use strict';

function up(db) {
  let rows;
  return [
    function getMeta(cb) {
      console.log('getMeta')

      db.sql(`SELECT id FROM people`).exec(function (err, result) {
        console.log('getMeta:err', err);
        console.log('getMeta:result', result);
        if (err) return cb(err);
        rows = result;
        cb();
      });
    },

    function updateMeta(cb) {
      console.log('ROWS', rows);
      cb();
    },
  ];
}

module.exports = {
  up: function (exec, cb) {
    exec(up, {transaction: true}, cb);
  }
};
