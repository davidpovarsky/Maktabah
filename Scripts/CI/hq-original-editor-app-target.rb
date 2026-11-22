#!/usr/bin/env ruby
# Use CocoaPods' original Xcodeproj dependency; never apply a global xcconfig.
require 'json'
require 'digest'
require 'shellwords'
require 'xcodeproj'

project_file, plan_file, receipt_file = ARGV
raise 'Expected project, exact app plan and receipt paths' unless ARGV.length == 3
plan = JSON.parse(File.read(plan_file))
original_bytes = File.binread(project_file)
raise 'Generated project changed before SDK integration' unless Digest::SHA256.hexdigest(original_bytes) == plan.fetch('before_project_sha256')
before = Xcodeproj::Plist.read_from_path(project_file)
project = Xcodeproj::Project.open(File.dirname(project_file))
targets = project.targets.select { |target| target.name == 'Maktabah-iOS' }
raise 'Missing or ambiguous original app target' unless targets.length == 1
target = targets.first
raise 'Target is not the original app' unless target.product_type == 'com.apple.product-type.application'
configs = target.build_configurations.select { |config| config.name == 'Debug' }
raise 'Missing or ambiguous original Debug configuration' unless configs.length == 1
config = configs.first
raise 'App bundle identity differs' unless config.build_settings.fetch('PRODUCT_BUNDLE_IDENTIFIER') == plan.fetch('bundle')
raise 'Wrong SDK app plan' unless plan.fetch('target') == target.name
raise 'Unsafe distribution path' unless plan.fetch('distribution_root').match?(%r{\Abuild/[A-Za-z0-9_./+-]+\z}) && !plan.fetch('distribution_root').split('/').include?('..')
raise 'Unsafe evidence path' unless plan.fetch('evidence').match?(%r{\Abuild/[A-Za-z0-9_./+-]+\z}) && !plan.fetch('evidence').split('/').include?('..')
raise 'Missing exact admission receipt digest' unless plan.fetch('receipt_sha256').match?(/\A[a-f0-9]{64}\z/)
names = plan.fetch('dynamic_frameworks')
raise 'Invalid actual dynamic SDK product list' unless names.is_a?(Array) && names.uniq == names && names.include?('AnytypeOriginalEditor.framework') && names.all? { |name| name.match?(/\A[A-Za-z0-9_.+-]+\.framework\z/) }

def append_settings(settings, key, additions)
  previous = settings[key]
  # These app settings are arrays in the original generated project, or absent.
  # Do not reinterpret an arbitrary new string/xcconfig expression silently.
  raise "Unexpected existing app setting shape: #{key}" unless previous.nil? || previous.is_a?(Array) || previous == '$(inherited)'
  items = previous.nil? || previous == '$(inherited)' ? ['$(inherited)'] : previous.dup
  additions.each { |value| items << value unless items.include?(value) }
  settings[key] = items
end

root = '$(SRCROOT)/' + plan.fetch('distribution_root')
settings = config.build_settings
{
  'FRAMEWORK_SEARCH_PATHS' => '/Frameworks',
  'SWIFT_INCLUDE_PATHS' => '/Modules',
  'LIBRARY_SEARCH_PATHS' => '/Libraries',
  'HEADER_SEARCH_PATHS' => '/Include'
}.each { |key, suffix| append_settings(settings, key, [root + suffix]) }
# A repeated -framework flag is semantically significant. Preserve the exact
# original linker tokens and append each complete original dependency pair.
old_flags = before.fetch('objects').fetch(config.uuid).fetch('buildSettings')['OTHER_LDFLAGS']
raise 'Unexpected original linker setting shape' unless old_flags.nil? || old_flags.is_a?(Array) || old_flags == '$(inherited)'
old_flags = ['$(inherited)'] if old_flags.nil? || old_flags == '$(inherited)'
settings['OTHER_LDFLAGS'] = old_flags.dup + names.flat_map { |name| ['-framework', name.delete_suffix('.framework')] }
append_settings(settings, 'LD_RUNPATH_SEARCH_PATHS', ['@executable_path/Frameworks'])

phase_name = '[Otzaria] Embed admitted original editor'
raise 'Refusing an existing SDK embed phase' if target.build_phases.any? { |phase| phase.respond_to?(:name) && phase.name == phase_name }
phase = target.new_shell_script_build_phase(phase_name)
phase.shell_path = '/bin/sh'
phase.show_env_vars_in_log = '0'
phase.always_out_of_date = '1'
receipt_relative = plan.fetch('evidence') + '/distribution-admission.json'
phase.input_paths = ['$(SRCROOT)/Scripts/CI/hq-original-editor-distribution.py', '$(SRCROOT)/' + receipt_relative]
phase.output_paths = []
phase.shell_script = <<~SCRIPT
  set -eu
  #{Shellwords.escape(plan.fetch('python'))} "$SRCROOT/Scripts/CI/hq-original-editor-distribution.py" embed \\
    --receipt #{Shellwords.escape(receipt_relative)} \\
    --receipt-sha256 #{Shellwords.escape(plan.fetch('receipt_sha256'))} \\
    --app "$TARGET_BUILD_DIR/$WRAPPER_NAME" \\
    --evidence #{Shellwords.escape(plan.fetch('evidence'))}
SCRIPT

begin
  expected_settings = Marshal.load(Marshal.dump(settings))
  project.save
  after = Xcodeproj::Plist.read_from_path(project_file)
  old_objects, new_objects = before.fetch('objects'), after.fetch('objects')
  raise 'SDK integration changed project metadata' unless before.reject { |key, _| key == 'objects' } == after.reject { |key, _| key == 'objects' }
  raise 'SDK integration added/dropped unrelated project objects' unless new_objects.keys.sort == (old_objects.keys + [phase.uuid]).sort
  old_objects.each do |id, value|
    next if [target.uuid, config.uuid].include?(id)
    raise "SDK integration changed unrelated object #{id}" unless new_objects[id] == value
  end
  old_target, new_target = old_objects.fetch(target.uuid), new_objects.fetch(target.uuid)
  raise 'SDK integration changed app target identity or dependencies' unless old_target.reject { |key, _| key == 'buildPhases' } == new_target.reject { |key, _| key == 'buildPhases' }
  raise 'SDK embed did not follow all original app phases' unless new_target.fetch('buildPhases') == old_target.fetch('buildPhases') + [phase.uuid]
  old_config, new_config = old_objects.fetch(config.uuid), new_objects.fetch(config.uuid)
  raise 'SDK integration changed configuration identity' unless old_config.reject { |key, _| key == 'buildSettings' } == new_config.reject { |key, _| key == 'buildSettings' }
  raise 'SDK app settings were not retained exactly' unless new_config.fetch('buildSettings') == expected_settings
  result = {
    'status' => 'APP_TARGET_ONLY_CONFIGURED', 'target' => target.name, 'configuration' => config.name,
    'target_uuid' => target.uuid, 'configuration_uuid' => config.uuid, 'phase_uuid' => phase.uuid,
    'xcodeproj_version' => Xcodeproj::VERSION, 'all_other_objects_unchanged' => true,
    'before_project_sha256' => Digest::SHA256.hexdigest(original_bytes),
    'after_project_sha256' => Digest::SHA256.file(project_file).hexdigest,
    'original_build_settings' => old_config.fetch('buildSettings'), 'app_build_settings' => expected_settings,
    'global_xcconfig' => false, 'codesign_on_copy' => false, 'remove_headers_on_copy' => false
  }
  File.write(receipt_file, JSON.pretty_generate(result) + "\n")
rescue Exception => error
  # Preserve the rejected generated project, then restore exactly the original
  # CocoaPods result. This occurs before any app build or simulator operation.
  begin
    File.binwrite(receipt_file + '.rejected-project.pbxproj', File.binread(project_file))
  ensure
    # Diagnostic retention failure must never bypass exact project restoration.
    Atomos.atomic_write(project_file) { |file| file.write(original_bytes) }
  end
  raise error
end
