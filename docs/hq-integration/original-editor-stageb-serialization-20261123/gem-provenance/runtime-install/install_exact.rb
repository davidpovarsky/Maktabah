require 'json'
require 'rubygems/installer'
rows = JSON.parse(File.read(ARGV.fetch(0))).fetch('packages')
rows.each do |row|
  installer = Gem::Installer.at(row.fetch('path'), install_dir: ENV.fetch('GEM_HOME'), bin_dir: File.join(ENV.fetch('GEM_HOME'), 'bin'), ignore_dependencies: true, document: [])
  spec = installer.spec
  raise 'package identity drift' unless spec.name == row.fetch('name') && spec.version.to_s == row.fetch('version') && spec.platform.to_s == 'ruby'
  installer.install
  puts JSON.generate(name: spec.name, version: spec.version.to_s, installed: true)
end
