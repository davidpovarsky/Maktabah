const path = require('path');
const upstreamDir = path.resolve(__dirname, '../Upstream');
const integrationDir = __dirname;
const repoRoot = path.resolve(__dirname, '../../..');

const { getDefaultConfig } = require(require.resolve('expo/metro-config', { paths: [upstreamDir] }));
const { mergeConfig } = require(require.resolve('@react-native/metro-config', { paths: [upstreamDir] }));

const defaultConfig = getDefaultConfig(upstreamDir);
const { assetExts, sourceExts } = defaultConfig.resolver;

const embeddedConfig = {
  watchFolders: [
    upstreamDir,
    integrationDir,
    repoRoot,
  ],
  transformer: {
    babelTransformerPath: require.resolve('react-native-svg-transformer', { paths: [upstreamDir] }),
  },
  resolver: {
    assetExts: assetExts.filter((ext) => ext !== 'svg'),
    sourceExts: [...sourceExts, 'svg'],
    extraNodeModules: {
      '@react-native-firebase/app': path.resolve(integrationDir, 'JS/mocks/firebase-app.js'),
      '@react-native-firebase/crashlytics': path.resolve(integrationDir, 'JS/mocks/firebase-crashlytics.js'),
      '@react-native-firebase/analytics': path.resolve(integrationDir, 'JS/mocks/firebase-analytics.js'),
      '@react-native-firebase/remote-config': path.resolve(integrationDir, 'JS/mocks/firebase-remote-config.js'),
    },
    nodeModulesPaths: [
      path.resolve(upstreamDir, 'node_modules'),
    ],
  },
};

module.exports = mergeConfig(defaultConfig, embeddedConfig);
