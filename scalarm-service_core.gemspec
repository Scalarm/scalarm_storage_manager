# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'scalarm/service_core/version'

Gem::Specification.new do |spec|
  spec.name          = 'scalarm-service_core'
  spec.version       = Scalarm::ServiceCore::VERSION
  spec.authors       = ['Jakub Liput']
  spec.email         = ['jakub.liput@gmail.com']
  spec.summary       = %q{Set of classes to build Scalarm services}
  spec.description   = %q{Set of classes to build Scalarm services.
Authentication and user modle, basic configuration, Grid proxy support,
InformationService client, parameters validator and other utils.
}
  spec.homepage      = 'https://github.com/Scalarm/scalarm-service_core'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'mocha'
  spec.add_dependency 'activesupport', '~> 4.1'
  spec.add_dependency 'actionpack', '~> 4.1'
end
