'use strict';

const crashlyticsInstance = {
  log: (...args) => console.log(...args),
  recordError: (...args) => Promise.resolve(),
  setUserId: () => Promise.resolve(),
  setAttribute: () => Promise.resolve(),
  setAttributes: () => Promise.resolve(),
  setCrashlyticsCollectionEnabled: () => Promise.resolve(),
  sendUnsentReports: () => Promise.resolve(),
  deleteUnsentReports: () => Promise.resolve(),
  checkForUnsentReports: () => Promise.resolve(false),
  didCrashOnPreviousExecution: () => Promise.resolve(false),
  error: (...args) => console.error(...args),
};

const fn = () => crashlyticsInstance;
fn.default = fn;
fn.getCrashlytics = () => crashlyticsInstance;
fn.log = (...args) => console.log(...args);
fn.recordError = (...args) => {
  console.error(...args);
  return Promise.resolve();
};
fn.setAttribute = () => {};
fn.setAttributes = () => {};
fn.setUserId = () => {};
fn.setCrashlyticsCollectionEnabled = () => {};
fn.error = (...args) => console.error(...args);

module.exports = fn;
