'use strict';
var npath = require('path');
function getName() {
  return npath.basename(process.cwd());
}

module.exports = {
  name: 'base name'
};
