'use strict';

const analyticsInstance = {
  logEvent: () => Promise.resolve(),
  setAnalyticsCollectionEnabled: () => Promise.resolve(),
  setDefaultEventParameters: () => Promise.resolve(),
  setUserId: () => Promise.resolve(),
  setUserProperty: () => Promise.resolve(),
  resetAnalyticsData: () => Promise.resolve(),
};

const fn = () => analyticsInstance;
fn.default = fn;
fn.getAnalytics = () => analyticsInstance;
fn.logEvent = () => Promise.resolve();
fn.setAnalyticsCollectionEnabled = () => Promise.resolve();
fn.setDefaultEventParameters = () => Promise.resolve();
fn.setUserId = () => Promise.resolve();
fn.setUserProperty = () => Promise.resolve();

module.exports = fn;
