'use strict';

const remoteConfigInstance = {
  getValue: () => ({ asString: () => '', asBoolean: () => false, asNumber: () => 0 }),
  fetchAndActivate: () => Promise.resolve(true),
  fetch: () => Promise.resolve(),
  activate: () => Promise.resolve(true),
  setDefaults: () => Promise.resolve(),
  getAll: () => ({}),
};

const fn = () => remoteConfigInstance;
fn.default = fn;
fn.getRemoteConfig = () => remoteConfigInstance;

module.exports = fn;
