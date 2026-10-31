'use strict';

const remoteConfigInstance = {
  getValue: () => ({ asString: () => '', asBoolean: () => false, asNumber: () => 0 }),
  fetchAndActivate: () => Promise.resolve(true),
  setDefaults: () => Promise.resolve(),
};

module.exports = () => remoteConfigInstance;
module.exports.default = () => remoteConfigInstance;
