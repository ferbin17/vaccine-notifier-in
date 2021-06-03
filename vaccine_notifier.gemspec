require_relative "lib/vaccine_notifier/version"

Gem::Specification.new do |spec|
  spec.name        = "vaccine_notifier"
  spec.version     = VaccineNotifier::VERSION
  spec.authors     = ["ferbin"]
  spec.email       = ["ferbin17@gmail.com"]
  spec.homepage    = "http://mygemserver.com"
  spec.summary     = "Summary of VaccineNotifier."
  spec.description = "Description of VaccineNotifier."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "http://mygemserver.com"
  spec.metadata["changelog_uri"] = "http://mygemserver.com"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.1.3"
  spec.add_dependency "clockwork"
  spec.add_dependency "daemons"
  spec.add_dependency "i18n"
end
