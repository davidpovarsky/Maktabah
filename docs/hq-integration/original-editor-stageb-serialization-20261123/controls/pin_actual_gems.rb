require 'json'
require 'digest'
require 'rbconfig'
expected = {
  'atomos' => '0.1.3', 'CFPropertyList' => '3.0.8', 'claide' => '1.1.0',
  'colored2' => '3.1.2', 'nanaimo' => '0.4.0', 'rexml' => '3.4.4',
  'nkf' => '0.2.0', 'base64' => '0.2.0', 'xcodeproj' => '1.28.1'
}
expected.each { |name, version| gem name, "= #{version}" }
require 'xcodeproj'
require 'nkf'
rows = expected.map do |name, version|
  spec = Gem.loaded_specs.fetch(name)
  raise "Wrong actual gem #{name}" unless spec.version.to_s == version
  { 'name' => name, 'version' => spec.version.to_s, 'path' => spec.full_gem_path }
end
File.write(ENV.fetch('OTZARIA_HELPER_GEM_RECEIPT'), JSON.pretty_generate({
  'ruby_version' => RUBY_VERSION, 'ruby_platform' => RUBY_PLATFORM,
  'ruby_executable' => RbConfig.ruby, 'ruby_sha256' => Digest::SHA256.file(RbConfig.ruby).hexdigest,
  'xcodeproj_version' => Xcodeproj::VERSION, 'gems' => rows,
  'scope' => 'Exact genuine gem source on portable Linux Ruby; no Apple or binary-framework qualification'
}) + "\n")
