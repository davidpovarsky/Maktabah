# Inspect exact PBX ownership before removing only the iOS app's shared links.
# This grants no compiler, runtime or UI credit.
module OriginalEditorSharedProductOwnership
  module_function

  def mentions?(value, identifier)
    case value
    when String then value == identifier
    when Array then value.any? { |item| mentions?(item, identifier) }
    when Hash then value.values.any? { |item| mentions?(item, identifier) }
    else false
    end
  end

  def referrers(objects, identifier)
    objects.select { |_, value| mentions?(value, identifier) }.keys.sort
  end

  def plan(objects, app_uuid, framework_uuid, dependencies)
    preserved = {}
    dependencies.each do |dependency|
      identifier, link = dependency.fetch('uuid'), dependency.fetch('link_uuid')
      expected = [app_uuid, link].sort
      raise 'Shared link input is owned by another phase' unless referrers(objects, link) == [framework_uuid]
      actual = referrers(objects, identifier)
      next if actual == expected
      # The original project shares exactly this package product object among
      # its iOS application and its two original macOS application targets.
      raise 'Unreviewed shared product owners' unless dependency.fetch('name') == 'ZIPFoundation'
      product = objects.fetch(identifier)
      raise 'Shared ZIP product identity differs' unless product.fetch('isa') == 'XCSwiftPackageProductDependency' &&
        product.fetch('productName') == 'ZIPFoundation'
      owners = objects.select do |uuid, value|
        uuid != app_uuid && value['isa'] == 'PBXNativeTarget' &&
          value.fetch('packageProductDependencies', []).include?(identifier)
      end
      raise 'Shared ZIP target membership differs' unless owners.values.map { |value| value.fetch('name') }.sort ==
        ['Maktabah', 'Maktabah-Direct']
      retained = {}
      owners.each do |uuid, owner|
        raise 'Shared ZIP owner is not the original application' unless
          owner.fetch('productType') == 'com.apple.product-type.application' &&
          owner.fetch('packageProductDependencies').count(identifier) == 1
        phases = owner.fetch('buildPhases').select { |phase| objects.fetch(phase).fetch('isa') == 'PBXFrameworksBuildPhase' }
        raise 'Ambiguous original ZIP owner framework phase' unless phases.length == 1
        phase = objects.fetch(phases.first)
        links = phase.fetch('files').select { |file| objects.fetch(file)['productRef'] == identifier }
        raise 'Ambiguous original ZIP owner link input' unless links.length == 1 &&
          objects.fetch(links.first).fetch('isa') == 'PBXBuildFile'
        raise 'Original ZIP link is referenced outside its owner phase' unless referrers(objects, links.first) == phases
        expected += [uuid, links.first]
        retained[uuid] = { 'name' => owner.fetch('name'), 'framework_phase' => phases.first, 'link' => links.first }
      end
      raise 'Shared ZIP product has an unknown referrer' unless actual == expected.sort
      preserved[identifier] = { 'product' => 'ZIPFoundation', 'owners' => retained }
    end
    preserved
  end
end
