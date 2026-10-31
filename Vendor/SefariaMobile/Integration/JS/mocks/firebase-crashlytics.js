'use strict';

const crashlyticsInstance = {
  log: () => {},
  recordError: () => {},
  setUserId: () => {},
  setAttribute: () => {},
  setCrashlyticsCollectionEnabled: () => {},
};

module.exports = () => crashlyticsInstance;
module.exports.default = () => crashlyticsInstance;
module.exports.getCrashlytics = () => crashlyticsInstance;
module.exports.log = (x) => console.log(x);
module.exports.recordError = (x) => console.error(x);
module.exports.setAttribute = () => {};
module.exports.error = (x) => console.error(x);
