# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gv/version'

Gem::Specification.new do |spec|
  spec.name          = 'gv'
  spec.version       = GV::VERSION
  spec.authors       = ['furunkel']
  spec.email         = ['furunkel@polyadic.com']
  spec.summary       = %q{Graphviz for Ruby, using libgvc via FFI}
  spec.homepage      = 'https://github.com/furunkel/gv'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'ffi', '>= 1.11'

  spec.add_development_dependency 'bundler', '>= 2'
  spec.add_development_dependency 'rake', '>= 10.0'
  spec.add_development_dependency 'yard', '>= 0.9'
  spec.add_development_dependency 'minitest', '>= 5.8'
  spec.add_development_dependency 'minitest-reporters', '> 1.1'
  spec.add_development_dependency 'rubocop', '>= 0.41'
end
