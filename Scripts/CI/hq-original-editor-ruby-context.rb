#!/usr/bin/env ruby
# Observe the original CocoaPods Ruby; never install or choose another gem.
module OriginalEditorRubyContext
  REQUEST = 'OTZARIA_ORIGINAL_EDITOR_RUBY_REQUEST'
  PARENT = 'OTZARIA_ORIGINAL_EDITOR_RUBY_PARENT'
  PROGRAM = 'OTZARIA_ORIGINAL_EDITOR_RUBY_PROGRAM'

  def self.file(path)
    resolved = File.realpath(path)
    raise 'Context input is not a regular file' unless File.file?(resolved)
    { 'path' => resolved, 'bytes' => File.size(resolved),
      'sha256' => Digest::SHA256.file(resolved).hexdigest }
  end

  def self.runtime
    { 'executable' => file(RbConfig.ruby), 'engine' => RUBY_ENGINE,
      'version' => RUBY_VERSION, 'patchlevel' => RUBY_PATCHLEVEL,
      'platform' => RUBY_PLATFORM }
  end

  def self.spec_identity(spec)
    { 'name' => spec.name, 'version' => spec.version.to_s,
      'full_gem_path' => File.expand_path(spec.full_gem_path),
      'loaded_from' => file(spec.loaded_from),
      'dependencies' => spec.runtime_dependencies.map { |d|
        { 'name' => d.name, 'requirement' => d.requirement.to_s }
      }.sort_by { |d| d.fetch('name') } }
  end

  # Ruby's default gems may have no standalone gem directory. Resolve only
  # their declared members within this exact Ruby installation, without
  # requiring them or changing the original process's activated dependencies.
  def self.default_sources(spec)
    return [] unless spec.default_gem?
    roots = %w[rubylibdir archdir].map { |key| RbConfig::CONFIG.fetch(key) }.
      select { |path| File.directory?(path) }.map { |path| File.realpath(path) }.uniq
    sources = []
    spec.files.each do |declared|
      raise 'Unsafe default gem member' unless declared.is_a?(String) &&
        !declared.empty? && !declared.start_with?(File::SEPARATOR) &&
        !declared.split(File::SEPARATOR).include?('..')
      relative = declared
      spec.require_paths.reject { |path| path.start_with?(File::SEPARATOR) }.each do |prefix|
        relative = relative.delete_prefix(prefix + File::SEPARATOR) if
          relative.start_with?(prefix + File::SEPARATOR)
      end
      roots.each do |root|
        candidate = File.join(root, relative)
        next unless File.file?(candidate)
        resolved = File.realpath(candidate)
        raise 'Default gem member escaped the original Ruby installation' unless
          roots.any? { |directory| resolved.start_with?(directory + File::SEPARATOR) }
        sources << resolved
      end
    end
    sources.uniq.sort
  end

  # Dependency-first order makes the later activation select the actual loaded
  # versions, including a version constrained by the original CocoaPods process.
  def self.closure(specs, features)
    ordered = []
    seen = {}
    visit = lambda do |name|
      return if seen[name]
      seen[name] = true
      spec = specs.fetch(name)
      spec.runtime_dependencies.each do |dependency|
        selected = specs.fetch(dependency.name)
        raise 'Loaded dependency does not satisfy original requirement' unless dependency.matches_spec?(selected)
        visit.call(dependency.name)
      end
      record = spec_identity(spec)
      root = record.fetch('full_gem_path')
      files = File.directory?(root) ?
        Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).select { |p| File.file?(p) } : []
      record['root_files'] = files.map { |p| File.realpath(p) }.uniq.sort
      # Default/extension gem features can live outside full_gem_path. Retain
      # only code actually loaded from this dependency's require directories.
      directories = spec.full_require_paths.select { |p| File.directory?(p) }.map { |p| File.realpath(p) }
      features.each do |feature|
        next unless File.file?(feature)
        actual = File.realpath(feature)
        files << actual if directories.any? { |directory| actual.start_with?(directory + File::SEPARATOR) }
      end
      files.concat(default_sources(spec))
      record['files'] = files.map { |p| file(p) }.uniq { |r| r.fetch('path') }.sort_by { |r| r.fetch('path') }
      raise "Original gem #{spec.name} has no retained source files" if record.fetch('files').empty?
      ordered << record
    end
    visit.call('xcodeproj')
    ordered
  end

  def self.write_exclusive(path, value)
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |stream|
      stream.write(JSON.pretty_generate(value) + "\n")
    end
  end

  def self.observe
    request_path = ENV[REQUEST]
    return unless request_path && ENV[PARENT] && ENV[PROGRAM]
    # Ruby children inherit RUBYOPT. They must remain entirely inert here:
    # no require, receipt, exit hook, changed exit status or gem activation.
    return unless Process.ppid.to_s == ENV[PARENT]
    original_argv = ARGV.dup
    return unless original_argv == ['install']
    original_pid = Process.pid
    original_parent = Process.ppid
    launched_program = ENV.fetch(PROGRAM)
    original_entry = File.realpath($PROGRAM_NAME)
    original_entry_bytes = File.binread(original_entry)
    at_exit do
      original_exception = $!
      original_exit = original_exception.is_a?(SystemExit) ? original_exception.status :
        (original_exception ? 1 : 0)
      loaded_specs = defined?(Gem) ? Gem.loaded_specs.dup : {}
      loaded_features = $LOADED_FEATURES.dup
      # Delay these observer requirements until the original program and its
      # subsequently registered at_exit hooks have returned.
      require 'json'
      require 'digest'
      require 'rbconfig'
      request = JSON.parse(File.read(request_path))
      entry = { 'path' => original_entry, 'bytes' => original_entry_bytes.bytesize,
                'sha256' => Digest::SHA256.hexdigest(original_entry_bytes) }
      raise 'Actual original Ruby entry changed' unless file(original_entry) == entry
      raise 'Original pod request identity changed' unless
        request.fetch('parent_pid') == original_parent &&
        request.fetch('program').fetch('path') == launched_program &&
        request.fetch('observer') == file(__FILE__) &&
        request.fetch('program') == file(launched_program) &&
        request.fetch('helper') == file(request.fetch('helper').fetch('path'))
      receipt = {
        'schema' => 1, 'nonce' => request.fetch('nonce'), 'parent_pid' => original_parent,
        'pid' => original_pid, 'argv' => original_argv, 'program' => file(launched_program),
        'ruby_entry' => entry,
        'observer' => file(__FILE__), 'helper' => request.fetch('helper'), 'original_exit_code' => original_exit
      }
      if original_exit == 0
        receipt['ruby'] = runtime
        receipt['gem_home'] = Gem.dir
        receipt['gem_paths'] = Gem.path
        receipt['cocoapods'] = spec_identity(loaded_specs.fetch('cocoapods'))
        receipt['xcodeproj_closure'] = closure(loaded_specs, loaded_features)
      end
      write_exclusive(request.fetch('receipt_path'), receipt)
    end
  end

  def self.launch
    require 'json'
    require 'digest'
    require 'rbconfig'
    require 'rubygems'
    receipt_path, receipt_sha, helper, *arguments = ARGV.drop(1)
    raise 'Invalid original helper launch arguments' unless arguments.length == 3
    raise 'Original pod receipt changed' unless Digest::SHA256.file(receipt_path).hexdigest == receipt_sha
    receipt = JSON.parse(File.read(receipt_path))
    raise 'Wrong original Ruby runtime' unless receipt.fetch('ruby') == runtime
    raise 'Original pod did not return successfully' unless receipt.fetch('original_exit_code') == 0
    raise 'Actual original Ruby entry changed' unless file(receipt.fetch('ruby_entry').fetch('path')) == receipt.fetch('ruby_entry')
    raise 'Original project helper changed' unless file(helper) == receipt.fetch('helper')
    Gem.use_paths(receipt.fetch('gem_home'), receipt.fetch('gem_paths'))
    raise 'Original Ruby gem search context differs' unless Gem.dir == receipt.fetch('gem_home') &&
      Gem.path == receipt.fetch('gem_paths')
    records = receipt.fetch('xcodeproj_closure')
    records.each do |record|
      raise 'Original gem specification changed' unless file(record.fetch('loaded_from').fetch('path')) == record.fetch('loaded_from')
      root = record.fetch('full_gem_path')
      root_files = File.directory?(root) ? Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).
        select { |p| File.file?(p) }.map { |p| File.realpath(p) }.uniq.sort : []
      raise 'Original gem source membership changed' unless root_files == record.fetch('root_files')
      record.fetch('files').each do |source|
        raise 'Original gem source changed' unless file(source.fetch('path')) == source
      end
      gem record.fetch('name'), "= #{record.fetch('version')}"
      declared_defaults = default_sources(Gem.loaded_specs.fetch(record.fetch('name')))
      raise 'Default gem runtime source membership changed' unless
        (declared_defaults - record.fetch('files').map { |source| source.fetch('path') }).empty?
    end
    require 'xcodeproj'
    records.each do |record|
      actual = spec_identity(Gem.loaded_specs.fetch(record.fetch('name')))
      expected = record.reject { |key, _| key == 'files' || key == 'root_files' }
      raise 'Actual Xcodeproj dependency activation differs' unless actual == expected
    end
    # This exact helper is separately source-bound by the caller. It still owns
    # all original target/delta/rollback assertions and its ordinary exit status.
    ARGV.replace(arguments)
    load helper
  end
end

if File.expand_path($PROGRAM_NAME) == File.expand_path(__FILE__)
  raise 'Unknown original Ruby context command' unless ARGV.first == '--launch'
  OriginalEditorRubyContext.launch
else
  OriginalEditorRubyContext.observe
end
