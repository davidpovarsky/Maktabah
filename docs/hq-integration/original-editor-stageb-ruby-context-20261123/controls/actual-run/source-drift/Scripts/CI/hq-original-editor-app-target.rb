require "json"
File.write(ENV.fetch("FIXTURE_HELPER_MARKER"), JSON.generate({fixture: true, arguments: ARGV}))
exit Integer(ENV.fetch("FIXTURE_HELPER_EXIT", "0"))
