'use strict';

const defaultApp = {
  name: '[DEFAULT]',
  options: {},
  automaticResourceManagement: false,
  automaticDataCollectionEnabled: true,
  delete: () => Promise.resolve(),
};

const firebase = {
  app: (name) => defaultApp,
  apps: [defaultApp],
  initializeApp: (options, config) => defaultApp,
  getApp: (name) => defaultApp,
  getApps: () => [defaultApp],
  DEFAULT_APP_NAME: '[DEFAULT]',
  utils: () => ({
    FilePath: {
      MAIN_BUNDLE: '',
      DOCUMENT_DIRECTORY: '',
      LIBRARY_DIRECTORY: '',
      CACHES_DIRECTORY: '',
    },
  }),
};

module.exports = firebase;
module.exports.default = firebase;
module.exports.firebase = firebase;
module.exports.initializeApp = (options, config) => defaultApp;
module.exports.getApp = (name) => defaultApp;
module.exports.getApps = () => [defaultApp];
module.exports.DEFAULT_APP_NAME = '[DEFAULT]';
module.exports.app = (name) => defaultApp;
module.exports.apps = [defaultApp];
