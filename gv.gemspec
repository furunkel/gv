# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gv/version'

Gem::Specification.new do |spec|
  spec.name          = "gv"
  spec.version       = GV::VERSION
  spec.authors       = ["furunkel"]
  spec.email         = ["julian@linux4you.it"]
  spec.summary       = %q{Graphviz for Ruby, using libgvc directly via FFI}
  spec.homepage      = "https://github.com/furunkel/gv"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest"

  spec.add_dependency "ffi"
end
