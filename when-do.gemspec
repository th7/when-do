# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'when-do/version'

Gem::Specification.new do |spec|
  spec.name          = "when-do"
  spec.version       = When::VERSION
  spec.authors       = ["TH"]
  spec.email         = ["tylerhartland7@gmail.com"]
  spec.description   = %q{Queues jobs when you want.}
  spec.summary       = %q{A very basic scheduler that can integrate with Sidekiq or Resque.}
  spec.homepage      = "https://github.com/th7/when-do"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'when-cron', '~> 1.0'
  spec.add_runtime_dependency 'redis', '~> 3.0'
  spec.add_runtime_dependency 'json', '~> 1.8'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake", '~> 10.4'
  spec.add_development_dependency "guard", '~> 2.1'
  spec.add_development_dependency "rspec", '~> 3.1'
  spec.add_development_dependency "guard-rspec", '~> 4.3'
  spec.add_development_dependency "pry", '~> 0.10'
end
