#!/usr/bin/env ruby
# Real generated-project ownership controls. No compilation or UI credit.
require 'json'
require 'digest'
require_relative 'original_editor_shared_product_ownership'

project_path, plan_path = ARGV
raise 'Expected actual project JSON and original admission plan' unless ARGV.length == 2
project = JSON.parse(File.read(project_path))
source_plan = JSON.parse(File.read(plan_path))
objects = project.fetch('objects')
app = objects.select { |_, object| object['isa'] == 'PBXNativeTarget' && object['name'] == 'Maktabah-iOS' }
raise 'Actual app target missing or duplicated' unless app.length == 1
app_uuid, app_object = app.first
phases = app_object.fetch('buildPhases').select { |uuid| objects.fetch(uuid)['isa'] == 'PBXFrameworksBuildPhase' }
raise 'Actual framework phase differs' unless phases.length == 1
phase_uuid = phases.first
names = source_plan.fetch('shared_runtime').fetch('host_products')
dependencies = app_object.fetch('packageProductDependencies').filter_map do |uuid|
  name = objects.fetch(uuid).fetch('productName')
  next unless names.include?(name)
  links = objects.fetch(phase_uuid).fetch('files').select { |link| objects.fetch(link)['productRef'] == uuid }
  raise 'Actual app link differs' unless links.length == 1
  { 'uuid' => uuid, 'name' => name, 'link_uuid' => links.first }
end
raise 'Actual shared dependency set differs' unless dependencies.map { |entry| entry.fetch('name') }.sort == names.sort
before = JSON.generate(objects)
observed = OriginalEditorSharedProductOwnership.plan(objects, app_uuid, phase_uuid, dependencies)
zip = dependencies.find { |entry| entry['name'] == 'ZIPFoundation' }
raise 'Original shared ZIP object was not retained' unless observed.keys == [zip.fetch('uuid')] &&
  observed.values.first.fetch('owners').values.map { |value| value.fetch('name') }.sort == ['Maktabah', 'Maktabah-Direct']
raise 'Read-only ownership observation mutated the project' unless JSON.generate(objects) == before
owner_uuid, owner = observed.values.first.fetch('owners').first
clone = lambda { |value| Marshal.load(Marshal.dump(value)) }
cases = {
  'unknown_product_referrer' => lambda { |copy, _| copy['UNKNOWN_REF'] = { 'isa' => 'PBXBuildFile', 'productRef' => zip.fetch('uuid') } },
  'different_owner_target' => lambda { |copy, _| copy.fetch(owner_uuid)['name'] = 'AnotherApplication' },
  'duplicate_owner_dependency' => lambda { |copy, _| copy.fetch(owner_uuid).fetch('packageProductDependencies') << zip.fetch('uuid') },
  'owner_link_in_another_phase' => lambda { |copy, _| copy['UNKNOWN_PHASE'] = { 'isa' => 'PBXFrameworksBuildPhase', 'files' => [owner.fetch('link')] } },
  'other_product_shared_by_targets' => lambda { |_, deps| deps.find { |entry| entry['name'] == 'ZIPFoundation' }['name'] = 'FloatingPanel' },
  'second_owner_link' => lambda { |copy, _| copy['EXTRA_LINK'] = { 'isa' => 'PBXBuildFile', 'productRef' => zip.fetch('uuid') }; copy.fetch(owner.fetch('framework_phase')).fetch('files') << 'EXTRA_LINK' },
  'app_link_in_another_phase' => lambda { |copy, _| copy['UNKNOWN_PHASE'] = { 'isa' => 'PBXFrameworksBuildPhase', 'files' => [zip.fetch('link_uuid')] } },
  'missing_original_owner_dependency' => lambda { |copy, _| copy.fetch(owner_uuid).fetch('packageProductDependencies').delete(zip.fetch('uuid')) }
}
rejections = {}
cases.each do |name, change|
  copy, deps = clone.call(objects), clone.call(dependencies)
  change.call(copy, deps)
  begin
    OriginalEditorSharedProductOwnership.plan(copy, app_uuid, phase_uuid, deps)
  rescue RuntimeError => error
    rejections[name] = error.message
  end
  raise 'Mutated ownership was accepted: ' + name unless rejections.key?(name)
end
puts JSON.pretty_generate({
  'status' => 'PASS_REAL_PROJECT_OWNERSHIP_AND_EIGHT_REJECTIONS',
  'project_json_sha256' => Digest::SHA256.file(project_path).hexdigest,
  'source_plan_sha256' => Digest::SHA256.file(plan_path).hexdigest,
  'shared_products' => dependencies.length,
  'preserved_other_targets' => observed,
  'rejected_mutations' => rejections,
  'compiler_or_ui_credit' => false
})
