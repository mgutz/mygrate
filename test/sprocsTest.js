var assert = require('chai').assert;
var sprocs = require('../lib/parseSprocs');
var fp = require('path');
var _ = require('lodash');

describe('parseSprocs', function() {
  it('should parse file with multiple sprocs', function(done) {
    var result = sprocs.parseFile(fp.join(__dirname, './sprocs_multi.sql'));
    var names = _.pluck(result, 'name')
    var expected = [
      'f_fangames_join',
      'f_fangames_set_teams',
      'f_fangames_replace_user',
      'f_fangames_finalize'
    ];

    assert.equal(result.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      assert.include(names, expected[i]);
    }
    done();
  });

  it('should parse a directory', function(done) {
    sprocs.parseDirPattern('test/*.sql', function(err, sprocs) {
      if (err) return done(err);
      console.log('sprocs', sprocs);

      var names = _.pluck(sprocs, 'name');
      assert(names.length > 0);
      console.log('names', names);
      done();
    });
  });
});


