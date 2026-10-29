const path = require('path');
const { getDefaultConfig } = require('expo/metro-config');
const { mergeConfig } = require('@react-native/metro-config');

const upstreamDir = path.resolve(__dirname, '../Upstream');
const integrationDir = __dirname;
const repoRoot = path.resolve(__dirname, '../../..');

const defaultConfig = getDefaultConfig(upstreamDir);
const { assetExts, sourceExts } = defaultConfig.resolver;

const embeddedConfig = {
  watchFolders: [
    upstreamDir,
    integrationDir,
    repoRoot,
  ],
  transformer: {
    babelTransformerPath: require.resolve('react-native-svg-transformer'),
  },
  resolver: {
    assetExts: assetExts.filter((ext) => ext !== 'svg'),
    sourceExts: [...sourceExts, 'svg'],
  },
};

module.exports = mergeConfig(defaultConfig, embeddedConfig);
