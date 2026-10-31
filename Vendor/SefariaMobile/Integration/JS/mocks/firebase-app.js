'use strict';

const defaultApp = {
  name: '[DEFAULT]',
  options: {},
};

const firebase = {
  app: () => defaultApp,
  apps: [defaultApp],
  initializeApp: () => defaultApp,
};

module.exports = firebase;
module.exports.default = firebase;
module.exports.initializeApp = () => defaultApp;
module.exports.getApp = () => defaultApp;
module.exports.getApps = () => [defaultApp];
