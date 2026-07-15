#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

project = Xcodeproj::Project.open('Maktabah.xcodeproj')
target = project.targets.find { |item| item.name == 'Maktabah-iOS' }
abort('Maktabah-iOS target was not found') unless target

group = project.main_group.find_subpath('ZayitSearch', true)
existing_sources = target.source_build_phase.files_references.compact

source_paths = Dir.glob('Vendor/ZayitSearchPort/Swift/*.swift').sort +
               Dir.glob('Source/ZayitSearch/*.swift').sort

source_paths.each do |path|
  file_ref = project.files.find { |ref| ref.path == path }
  file_ref ||= group.new_file(path)
  next if existing_sources.include?(file_ref)

  target.add_file_references([file_ref])
  existing_sources << file_ref
  puts "Added #{path} to #{target.name}"
end

framework_path = 'Vendor/ZayitSearchPort/build/MaktabahZayitSearch.xcframework'
abort("#{framework_path} was not found. Build it before configuring Xcode.") unless File.exist?(framework_path)

framework_ref = project.files.find { |ref| ref.path == framework_path }
framework_ref ||= group.new_file(framework_path)
linked_refs = target.frameworks_build_phase.files_references.compact
unless linked_refs.include?(framework_ref)
  target.frameworks_build_phase.add_file_reference(framework_ref)
  puts "Linked #{framework_path} to #{target.name}"
end

project.save
