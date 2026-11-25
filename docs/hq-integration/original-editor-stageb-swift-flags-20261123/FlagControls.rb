require 'json'
require 'digest'
source_path, input_path, mode = ARGV
source = File.binread(source_path)
inputs = JSON.parse(File.read(input_path))
start_marker = "  old_swift_flags = before.fetch('objects').fetch(config.uuid).fetch('buildSettings')['OTHER_SWIFT_FLAGS']\n"
end_marker = "\nend\nsearch_paths.each"
raise 'Ambiguous source extraction' unless source.scan(start_marker).length == 1 && source.scan(end_marker).length == 1
first = source.index(start_marker)
last = source.index(end_marker, first)
block = source[first...last]
line = source[0...first].count("\n") + 1
run = lambda do |value, absent = false|
  config = Struct.new(:uuid).new('F305776D2FA46222005732C6')
  original_settings = absent ? {} : {'OTHER_SWIFT_FLAGS' => value}
  before = {'objects' => {config.uuid => {'buildSettings' => original_settings}}}
  maps = inputs.fetch('maps').freeze
  root = inputs.fetch('root')
  settings = {}
  eval(block, binding, source_path, line)
  settings.fetch('OTHER_SWIFT_FLAGS')
end
if mode == '--baseline-only'
  run.call(inputs.fetch('actual_flags'))
  raise 'Baseline unexpectedly accepted the authenticated string'
end
result = {status: 'RUNNING', scope: 'ACTUAL_EXTRACTED_RUBY_FLAG_BLOCK_ONLY',
          source_sha256: Digest::SHA256.hexdigest(source),
          block_sha256: Digest::SHA256.hexdigest(block),
          input_sha256: Digest::SHA256.file(input_path).hexdigest,
          ruby: RUBY_DESCRIPTION, cases: [], assertions: 0,
          xcodeproj_project_mutation: 'NOT_RUN', apple_app_runtime: 'NOT_RUN'}
check = lambda do |value, name|
  result[:assertions] += 1
  raise name unless value
end
reject = lambda do |value|
  begin
    run.call(value)
  rescue RuntimeError => e
    check.call(e.message == 'Unexpected original Swift flag shape', 'Wrong rejection reason')
    next
  end
  raise 'Unexpected flag shape accepted'
end
suffix = inputs.fetch('maps').flat_map { |path| ['-Xcc', '-fmodule-map-file=' + inputs.fetch('root') + '/' + path] }
actual = run.call(inputs.fetch('actual_flags').freeze)
check.call(actual == ['$(inherited)', '-D', 'EXPO_CONFIGURATION_DEBUG'] + suffix, 'Exact Debug literal tokens or Clang pairs changed')
check.call(actual.count('-Xcc') == 19 && actual.length == 41, 'Repeated complete pairs lost')
result[:cases] << 'authenticated_debug_string_and_all19_pairs'
legacy = ['$(inherited)', '-D', 'OLD', '-D', 'OLD', '-Xcc', '-DLEGACY'].freeze
check.call(run.call(legacy) == legacy + suffix, 'Legacy array order or duplicate tokens changed')
check.call(legacy == ['$(inherited)', '-D', 'OLD', '-D', 'OLD', '-Xcc', '-DLEGACY'], 'Input array mutated')
result[:cases] << 'legacy_array_order_duplicates_and_input_unchanged'
check.call(run.call(nil) == ['$(inherited)'] + suffix, 'Nil behavior changed')
check.call(run.call(nil, true) == ['$(inherited)'] + suffix, 'Absent behavior changed')
result[:cases] << 'nil_and_absent_legacy_behavior'
check.call(run.call('$(inherited)') == ['$(inherited)'] + suffix, 'Inherited spelling changed')
result[:cases] << 'exact_inherited_legacy_behavior'
['', '$(inherited) -D EXPO_CONFIGURATION_RELEASE',
 '$(inherited) -D EXPO_CONFIGURATION_DEBUG -D EXTRA',
 ' $(inherited) -D EXPO_CONFIGURATION_DEBUG',
 '$(inherited)  -D EXPO_CONFIGURATION_DEBUG',
 '$(inherited) -DEXPO_CONFIGURATION_DEBUG',
 '$(inherited) -D EXPO_CONFIGURATION_DEBUG '].each { |value| reject.call(value) }
result[:cases] << 'other_string_expressions_still_refused'
[false, true, 12, {}, 2.5].each { |value| reject.call(value) }
result[:cases] << 'other_nonarray_shapes_still_refused'
result[:status] = 'PASS'
puts JSON.pretty_generate(result)
