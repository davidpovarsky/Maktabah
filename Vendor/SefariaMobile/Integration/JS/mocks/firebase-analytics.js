'use strict';

const analyticsInstance = {
  logEvent: () => Promise.resolve(),
  setAnalyticsCollectionEnabled: () => Promise.resolve(),
  setDefaultEventParameters: () => Promise.resolve(),
};

module.exports = () => analyticsInstance;
module.exports.default = () => analyticsInstance;
module.exports.getAnalytics = () => analyticsInstance;
module.exports.logEvent = () => Promise.resolve();
module.exports.setAnalyticsCollectionEnabled = () => Promise.resolve();
module.exports.setDefaultEventParameters = () => Promise.resolve();
