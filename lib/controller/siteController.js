/**
 * External dependencies.
 */

var _      = require('underscore');
var extend = require('extend');
var extend = require('extend');

/**
 * Internal dependencies.
 */

var render = require('../../lib/util/render');

/**
 * Methods.
 */

function homepage(req, res) {
  render.page(req, res, 'page/homepage', {
    foo: 'bar'
  });
}

/**
 * Exports.
 */

module.exports = {
  homepage: homepage
};