# frozen_string_literal: true

require_relative 'lib/leopard/version'

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name = 'leopard'
  spec.version = Rubyists::Leopard::VERSION
  spec.authors = ['bougyman']
  spec.email = ['bougyman@users.noreply.github.com']

  spec.summary = 'A server to supervise concurrent NATS ServiceApi workers.'
  spec.description = 'Leopard is a puma-like server for managing concurrent NATS ServiceApi endpoint workers'
  spec.homepage = 'https://github.com/rubyists/leopard'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'concurrent-ruby', '~> 1.1'
  spec.add_dependency 'dry-configurable', '~> 1.3'
  spec.add_dependency 'dry-monads', '~> 1.9'
  spec.add_dependency 'nats-pure', '~> 2.5'
  spec.add_dependency 'semantic_logger', '~> 4'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
  spec.metadata['rubygems_mfa_required'] = 'true'
end
