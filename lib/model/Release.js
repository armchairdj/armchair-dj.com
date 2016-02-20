/**
 * External dependencies.
 */

var _                     = require('underscore');
var extend                = require('extend');
var passportLocalMongoose = require('passport-local-mongoose');

var mongoose              = require('mongoose');

/**
 * Internal dependencies.
 */

var metaData = require('../../lib/model/plugin/metaData')

/**
 * Constants.
 */

var TYPES = [
  'album',
  'song'
];

/**
 * Schema.
 */

var schema = new mongoose.Schema({
  artist: {
    type:     String,
    trim:     true,
    required: true
  },

  title: {
    type:     String,
    trim:     true,
    required: true
  },

  year: {
    type:     String,
    trim:     true,
    required: true
  },

  type: {
    type:     String,
    required: true
  },

  url: {
    type:     String,
    trim:     true
  }
});

/**
 * Statics.
 */

schema.statics = {

};

/**
 * Methods.
 */

schema.methods = {

};

/**
 * Plugins.
 */

schema.plugin(metaData);

/**
 * Methods.
 */


/**
 * Exports.
 */

module.exports = require('../../lib/model/util/findOrCreate')('Release', schema);