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

shared = plan.fetch('admission_schema', 1) == 3
removed_object_ids = []
shared_product_ids = []
shared_build_file_ids = []
shared_framework_phase = nil
pod_source_proof = {}
pod_projection_path = nil
pod_projection_before = nil
pod_projection_after = nil
source_root = File.expand_path('..', File.dirname(project_file))

def object_mentions?(value, identifier)
  case value
  when String then value == identifier
  when Array then value.any? { |item| object_mentions?(item, identifier) }
  when Hash then value.values.any? { |item| object_mentions?(item, identifier) }
  else false
  end
end

if shared
  contract = plan.fetch('shared_runtime')
  raise 'Unbound native shared provider' unless contract.fetch('producer_identity').fetch('source_sha') == plan.fetch('source_sha')
  products = contract.fetch('host_products')
  raise 'Wrong shared Host product membership' unless products == [
    'HanlinHostContracts', 'HanlinAgentCore', 'HanlinChatCore', 'HanlinScriptUI',
    'HanlinChatUI', 'HanlinPresentationKit', 'HanlinRichUI', 'HanlinPlatformContracts',
    'FloatingPanel', 'TorahInspectorCore', 'TorahInspectorUI', 'ZIPFoundation'
  ]
  dependencies = target.package_product_dependencies.select { |item| products.include?(item.product_name) }
  raise 'Shared Host product is missing or repeated' unless dependencies.map(&:product_name).sort == products.sort
  phases = target.build_phases.select { |item| item.isa == 'PBXFrameworksBuildPhase' }
  raise 'Ambiguous original app framework link phase' unless phases.length == 1
  shared_framework_phase = phases.first
  build_files = shared_framework_phase.files.select { |item| dependencies.include?(item.product_ref) }
  raise 'Missing original shared package link input' unless build_files.map { |item| item.product_ref.product_name }.sort == products.sort
  old_objects = before.fetch('objects')
  dependencies.each do |dependency|
    link = build_files.find { |item| item.product_ref == dependency }
    referrers = old_objects.select { |_, value| object_mentions?(value, dependency.uuid) }.keys.sort
    raise 'Shared product is owned by another target' unless referrers == [target.uuid, link.uuid].sort
    refs = old_objects.select { |_, value| object_mentions?(value, link.uuid) }.keys
    raise 'Shared link input is owned by another phase' unless refs == [shared_framework_phase.uuid]
  end
  shared_product_ids = dependencies.map(&:uuid)
  shared_build_file_ids = build_files.map(&:uuid)
  removed_object_ids = shared_product_ids + shared_build_file_ids

  route = plan.fetch('shared_pod_link_route')
  expected_path = 'Pods/Target Support Files/Pods-Maktabah-iOS/Pods-Maktabah-iOS.debug.xcconfig'
  raise 'Unreviewed generated CocoaPods configuration' unless route.fetch('path') == expected_path
  pod_projection_path = File.join(source_root, expected_path)
  raise 'App does not inherit the selected Debug Pod configuration' unless config.base_configuration_reference &&
    File.realpath(config.base_configuration_reference.real_path) == File.realpath(pod_projection_path)
  pod_projection_before = File.binread(pod_projection_path)
  raise 'Generated Pod configuration changed before admission' unless Digest::SHA256.hexdigest(pod_projection_before) == route.fetch('before_sha256')
  old_line, new_line = route.fetch('before_line'), route.fetch('after_line')
  raise 'Ambiguous exact Pod linker preimage' unless pod_projection_before.scan(Regexp.new(Regexp.escape(old_line))).length == 1
  pod_projection_after = pod_projection_before.sub(old_line, new_line)
  raise 'Generated Pod linker transformation differs' unless
    Digest::SHA256.hexdigest(pod_projection_after) == route.fetch('after_sha256') &&
    pod_projection_after.sub(new_line, old_line) == pod_projection_before &&
    route.fetch('other_linker_inputs_unchanged') == true

  pod_project_file = File.join(source_root, 'Pods/Pods.xcodeproj/project.pbxproj')
  pod_project_before = File.binread(pod_project_file)
  pod_project = Xcodeproj::Project.open(File.dirname(pod_project_file))
  contracts = route.fetch('pod_source_contracts')
  raise 'Missing exact Pod source contracts' unless contracts.keys.sort == route.fetch('shared_pod_libraries').sort
  contracts.each do |pod, source_contract|
    candidates = pod_project.targets.select { |item| item.name == pod }
    raise "Ambiguous actual Pod target: #{pod}" unless candidates.length == 1
    pod_target = candidates.first
    sources = pod_target.build_phases.select { |item| item.isa == 'PBXSourcesBuildPhase' }
    raise "Missing actual Pod sources phase: #{pod}" unless sources.length == 1
    actual_sources, generated_sources = {}, {}
    pod_root = File.realpath(File.join(source_root, 'Pods', pod))
    sources.first.files.each do |item|
      raise "Missing actual Pod source reference: #{pod}" unless item.file_ref
      source = File.realpath(item.file_ref.real_path)
      content = File.binread(source)
      if source.start_with?(pod_root + '/')
        relative = source.delete_prefix(pod_root + '/')
        expected = source_contract.fetch('files').fetch(relative)
        raise "Host compiles different shared source: #{pod}/#{relative}" unless
          content.bytesize == expected.fetch('bytes') && Digest::SHA256.hexdigest(content) == expected.fetch('sha256')
        raise 'Repeated actual shared Pod source' if actual_sources.key?(relative)
        actual_sources[relative] = expected.fetch('sha256')
      else
        dummy = File.join(source_root, 'Pods/Target Support Files', pod, pod + '-dummy.m')
        expected_dummy = "#import <Foundation/Foundation.h>\n@interface PodsDummy_#{pod} : NSObject\n@end\n@implementation PodsDummy_#{pod}\n@end\n"
        raise "Unreviewed generated shared Pod implementation: #{source}" unless source == File.realpath(dummy) && content == expected_dummy
        generated_sources[source.delete_prefix(source_root + '/')] = Digest::SHA256.hexdigest(content)
      end
    end
    raise "Empty original Pod implementation: #{pod}" if actual_sources.empty?
    pod_source_proof[pod] = { 'revision' => source_contract.fetch('revision'),
                             'actual_sources' => actual_sources, 'unchanged_generated_dummy_sources' => generated_sources }
  end
  raise 'Inspecting original Pod targets changed their project' unless File.binread(pod_project_file) == pod_project_before
  build_files.each(&:remove_from_project)
  dependencies.each(&:remove_from_project)
end

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
search_paths = {
  'FRAMEWORK_SEARCH_PATHS' => '/Frameworks',
  'SWIFT_INCLUDE_PATHS' => '/Modules',
  'LIBRARY_SEARCH_PATHS' => '/Libraries',
  'HEADER_SEARCH_PATHS' => '/Include'
}
if [2, 3].include?(plan.fetch('admission_schema', 1))
  context = plan.fetch('clang_import_context')
  raise 'Unbound original Clang context' unless context.fetch('producer_identity').fetch('source_sha') == plan.fetch('source_sha')
  maps, headers = context.fetch('module_maps'), context.fetch('header_search_paths')
  safe_path = lambda { |value| value.is_a?(String) && value.match?(%r{\A(?:[A-Za-z0-9_.+-]+/)*[A-Za-z0-9_.+-]+\z}) && !value.split('/').any? { |part| ['.', '..'].include?(part) } }
  raise 'Wrong original Clang module-map closure' unless maps.is_a?(Array) && (shared ? (1..128).include?(maps.length) : maps.length == 19) && maps.uniq == maps && maps.all? { |path| safe_path.call(path) && path.start_with?('Clang/') && path.end_with?('.modulemap') }
  raise 'Wrong original Clang header-root closure' unless headers.is_a?(Array) && (shared ? (1..256).include?(headers.length) : headers.length == 19) && headers.uniq == headers && headers.all? { |path| safe_path.call(path) && (path == 'Include' || path.start_with?('Clang/Packages/')) }
  import_root = root
  if plan.key?('host_clang_context')
    host = plan.fetch('host_clang_context')
    raise 'Unbound host Clang context' unless host.fetch('producer_identity') == context.fetch('producer_identity')
    raise 'Unresolved host Clang runtime collision' unless host.fetch('status') == 'HOST_CLANG_CONTEXT_COMPOSED' && host.fetch('runtime_collisions') == []
    maps, headers = host.fetch('module_maps'), host.fetch('header_search_paths')
    raise 'Wrong host Clang module closure' unless maps.is_a?(Array) && maps.length == context.fetch('module_maps').length && maps.uniq == maps && maps.all? { |path| safe_path.call(path) && (path.start_with?('build/') || (shared && path.start_with?('Pods/Headers/Public/'))) && path.end_with?('.modulemap') }
    raise 'Wrong host Clang header closure' unless headers.is_a?(Array) && headers.length == context.fetch('header_search_paths').length && headers.uniq == headers && headers.all? { |path| safe_path.call(path) && (path.start_with?('build/') || (shared && path.start_with?('Pods/Headers/Public/'))) }
    import_root = '$(SRCROOT)'
  end
  search_paths.delete('HEADER_SEARCH_PATHS')
  append_settings(settings, 'HEADER_SEARCH_PATHS', headers.map { |path| import_root + '/' + path })
  old_swift_flags = before.fetch('objects').fetch(config.uuid).fetch('buildSettings')['OTHER_SWIFT_FLAGS']
  # Preserve the exact CocoaPods-generated Debug spelling observed in the
  # authenticated app project; other string expressions remain inadmissible.
  if old_swift_flags == '$(inherited) -D EXPO_CONFIGURATION_DEBUG'
    old_swift_flags = ['$(inherited)', '-D', 'EXPO_CONFIGURATION_DEBUG']
  end
  raise 'Unexpected original Swift flag shape' unless old_swift_flags.nil? || old_swift_flags.is_a?(Array) || old_swift_flags == '$(inherited)'
  old_swift_flags = ['$(inherited)'] if old_swift_flags.nil? || old_swift_flags == '$(inherited)'
  # Every module-map argument needs its own -Xcc; individual-token deduplication
  # would silently pass later arguments to the wrong compiler frontend.
  settings['OTHER_SWIFT_FLAGS'] = old_swift_flags.dup + maps.flat_map { |path| ['-Xcc', '-fmodule-map-file=' + import_root + '/' + path] }
end
search_paths.each { |key, suffix| append_settings(settings, key, [root + suffix]) }
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
  # Xcodeproj 1.28.1 serializes these two observed array settings as strings.
  # Preserve their exact tokens and compare the complete saved settings hash.
  serialized_array_setting_tokens = {}
  ['OTHER_SWIFT_FLAGS', 'SWIFT_INCLUDE_PATHS'].each do |key|
    value = expected_settings[key]
    next unless value.is_a?(Array)
    raise "Non-string token in serialized app setting: #{key}" unless value.all? { |token| token.is_a?(String) }
    serialized_array_setting_tokens[key] = value.dup
    expected_settings[key] = value.join(' ')
  end
  Atomos.atomic_write(pod_projection_path) { |file| file.write(pod_projection_after) } if shared
  project.save
  after = Xcodeproj::Plist.read_from_path(project_file)
  old_objects, new_objects = before.fetch('objects'), after.fetch('objects')
  raise 'SDK integration changed project metadata' unless before.reject { |key, _| key == 'objects' } == after.reject { |key, _| key == 'objects' }
  raise 'SDK integration added/dropped unrelated project objects' unless new_objects.keys.sort == ((old_objects.keys - removed_object_ids) + [phase.uuid]).sort
  old_objects.each do |id, value|
    next if ([target.uuid, config.uuid, shared_framework_phase&.uuid] + removed_object_ids).include?(id)
    raise "SDK integration changed unrelated object #{id}" unless new_objects[id] == value
  end
  old_target, new_target = old_objects.fetch(target.uuid), new_objects.fetch(target.uuid)
  raise 'SDK integration changed app target identity or dependencies' unless old_target.reject { |key, _| ['buildPhases', *(shared ? ['packageProductDependencies'] : [])].include?(key) } == new_target.reject { |key, _| ['buildPhases', *(shared ? ['packageProductDependencies'] : [])].include?(key) }
  raise 'SDK embed did not follow all original app phases' unless new_target.fetch('buildPhases') == old_target.fetch('buildPhases') + [phase.uuid]
  old_config, new_config = old_objects.fetch(config.uuid), new_objects.fetch(config.uuid)
  raise 'SDK integration changed configuration identity' unless old_config.reject { |key, _| key == 'buildSettings' } == new_config.reject { |key, _| key == 'buildSettings' }
  raise 'SDK app settings were not retained exactly' unless new_config.fetch('buildSettings') == expected_settings
  if shared
    raise 'App removed a nonshared package capability' unless new_target.fetch('packageProductDependencies') == old_target.fetch('packageProductDependencies').reject { |id| shared_product_ids.include?(id) }
    old_links, new_links = old_objects.fetch(shared_framework_phase.uuid), new_objects.fetch(shared_framework_phase.uuid)
    raise 'App changed another framework link input' unless
      old_links.reject { |key, _| key == 'files' } == new_links.reject { |key, _| key == 'files' } &&
      new_links.fetch('files') == old_links.fetch('files').reject { |id| shared_build_file_ids.include?(id) }
    raise 'Generated Pod link route changed during project save' unless File.binread(pod_projection_path) == pod_projection_after
  end
  inverse = Marshal.load(Marshal.dump(after))
  inverse.fetch('objects').delete(phase.uuid)
  [target.uuid, config.uuid, shared_framework_phase&.uuid, *removed_object_ids].compact.each do |id|
    inverse.fetch('objects')[id] = old_objects.fetch(id)
  end
  raise 'Complete original generated project inverse differs' unless inverse == before
  result = {
    'status' => 'APP_TARGET_ONLY_CONFIGURED', 'target' => target.name, 'configuration' => config.name,
    'target_uuid' => target.uuid, 'configuration_uuid' => config.uuid, 'phase_uuid' => phase.uuid,
    'xcodeproj_version' => Xcodeproj::VERSION, 'all_other_objects_unchanged' => true,
    'before_project_sha256' => Digest::SHA256.hexdigest(original_bytes),
    'after_project_sha256' => Digest::SHA256.file(project_file).hexdigest,
    'original_build_settings' => old_config.fetch('buildSettings'), 'app_build_settings' => expected_settings,
    'serialized_array_setting_tokens' => serialized_array_setting_tokens,
    'global_xcconfig' => false, 'codesign_on_copy' => false, 'remove_headers_on_copy' => false,
    'whole_project_inverse_exact' => true,
    'shared_implementation_route' => shared,
    'reused_shared_product_ids' => shared_product_ids,
    'reused_shared_link_ids' => shared_build_file_ids,
    'actual_pod_source_membership' => pod_source_proof,
    'generated_debug_pod_configuration' => shared ? {
      'path' => plan.fetch('shared_pod_link_route').fetch('path'),
      'before_sha256' => Digest::SHA256.hexdigest(pod_projection_before),
      'after_sha256' => Digest::SHA256.hexdigest(pod_projection_after),
      'only_verified_shared_library_link_inputs_changed' => true
    } : nil
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
    Atomos.atomic_write(pod_projection_path) { |file| file.write(pod_projection_before) } if shared
  end
  raise error
end
