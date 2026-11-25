# Test-only fault after the real Xcodeproj save; never loaded in CI/product code.
require 'xcodeproj'
module OtzariaOwnedPostSaveCorruption
  def save(*args, **kwargs)
    result = super
    file = path.join('project.pbxproj')
    File.binwrite(ENV.fetch('OTZARIA_FIRST_SAVE'), File.binread(file))
    target = targets.find { |item| item.name == 'Maktabah-iOS' }
    config = target.build_configurations.find { |item| item.name == 'Debug' }
    config.build_settings['CODE_SIGN_STYLE'] = 'OWNED_TEST_CORRUPTION'
    super
    result
  end
end
Xcodeproj::Project.prepend(OtzariaOwnedPostSaveCorruption)
