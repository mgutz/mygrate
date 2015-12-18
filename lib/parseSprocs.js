var fs = require('fs');
var glob = require('glob');

var sprocNameRe = /^\s*create function\s(\w+(\.(\w+))?)/mi;

/**
 * Parse function name.
 */
function parseSprocName(udf) {
  var matches = udf.match(sprocNameRe);
  if (!matches) {
    return null;
  }
  return matches[1];
}

/**
 * Calculate a 32 bit FNV-1a hash
 * Found here: https://gist.github.com/vaiorabbit/5657561
 * Ref.: http://isthe.com/chongo/tech/comp/fnv/
 *
 * @param {string} str the input value
 * @param {boolean} [asString=false] set to true to return the hash value as
 *     8-digit hex string instead of an integer
 * @param {integer} [seed] optionally pass the hash of the previous chunk
 * @returns {integer | string}
 */
function hashFnv32a(str, asString, seed) {
  /*jshint bitwise:false */
  var i, l, hval = (seed === undefined) ? 0x811c9dc5 : seed;

  for (i = 0, l = str.length; i < l; i++) {
    hval ^= str.charCodeAt(i);
    hval += (hval << 1) + (hval << 4) + (hval << 7) + (hval << 8) + (hval << 24);
  }
  if (asString) {
    // Convert to 8 digit hex string
    return ("0000000" + (hval >>> 0).toString(16)).substr(-8);
  }
  return hval >>> 0;
}

/**
 * Parse filename for user defined functions and returns
 * an object by function name and body.
 */
function parseFile(filename) {
  var results = [];
  var content = fs.readFileSync(filename, 'utf8');
  if (!content) {
    throw new Error('SQL file does not have any sprocs: ' + filename);
  }

  var sprocs = content.split(/^GO$/mg)
  for (var i = 0; i < sprocs.length; i++) {
    var body = sprocs[i];
    var name = parseSprocName(sprocs[i]);
    results.push({
      name: name,
      body: body,
      crc: hashFnv32a(body, true)
    });
  }

  return results;
}
exports.parseFile = parseFile;

/**
 * Parses a directory for sproc files.
 */
exports.parseDirPattern = function parseDir(pattern, cb) {
  glob(pattern, function(err, files) {
    if (err) return cb(err);
    var results = [];

    for (var i = 0; i < files.length; i++) {
      var sprocs = parseFile(files[i]);
      if (sprocs) {
        results = results.concat(sprocs);
      }
    }
    return cb(null, results);
  });
}

