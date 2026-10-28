ENV['RCT_NEW_ARCH_ENABLED'] = '1'

upstream_dir = File.expand_path('Vendor/SefariaMobile/Upstream', __dir__)

require File.join(File.dirname(`node --print "require.resolve('expo/package.json', {paths: ['#{upstream_dir}']})"`), "scripts/autolinking")
require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "react-native/scripts/react_native_pods.rb",
    {paths: [process.argv[1]]},
  )', upstream_dir]).strip

min_ios_version_supported = '15.5'
platform :ios, min_ios_version_supported
prepare_react_native_project!

$RNFirebaseAnalyticsWithoutAdIdSupport = true
production = ENV["PRODUCTION"] == "1"

target 'Maktabah' do
  project 'Maktabah.xcodeproj'

  pod 'Firebase', :modular_headers => true
  pod 'FirebaseCoreInternal', :modular_headers => true
  pod 'GoogleUtilities', :modular_headers => true
  pod 'FirebaseCrashlytics', :modular_headers => true
  pod 'FirebaseCore', :modular_headers => true
  pod 'FirebaseInstallations', :modular_headers => true
  pod 'GoogleDataTransport', :modular_headers => true
  pod 'nanopb', :modular_headers => true
  pod 'FirebaseRemoteConfig', :modular_headers => true
  pod 'FirebaseABTesting', :modular_headers => true
  pod 'FirebaseSessions', :modular_headers => true
  pod 'FirebaseCoreExtension', :modular_headers => true
  pod 'RecaptchaInterop', :modular_headers => true
  pod 'AppCheckCore', :modular_headers => true

  use_expo_modules!(
    :search_paths => [upstream_dir]
  )

  post_integrate do |installer|
    begin
      expo_patch_react_imports!(installer)
    rescue => e
      Pod::UI.warn e
    end
  end

  $config = use_native_modules!(
    :project_root => upstream_dir
  )

  use_react_native!(
    :path => $config[:reactNativePath],
    :production => production,
    :app_path => upstream_dir
  )
end

post_install do |installer|
  react_native_post_install(
    installer,
    $config[:reactNativePath],
    :mac_catalyst_enabled => false
  )
end
