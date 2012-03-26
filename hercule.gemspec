# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hercule/version"

Gem::Specification.new do |s|
  s.name        = "hercule"
  s.version     = Hercule::VERSION
  s.authors     = ["Dylan Paris"]
  s.email       = ["dylan.paris+github@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Document Classification Engine}
  s.description = %q{A flexible document classification gem}

  s.rubyforge_project = "hercule"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency "gtokenizer", "~> 1.0.0"
  s.add_runtime_dependency "fast-stemmer", "~> 1.0.0"
  s.add_runtime_dependency "uuid", "~> 2.3.5"
  s.add_runtime_dependency "libsvm-ruby-swig", "~> 0.4.0"
  s.add_runtime_dependency "mongo", "~> 1.6.1"
  s.add_runtime_dependency "bson_ext", "~> 1.6.1"

  s.add_development_dependency "rspec", "~> 2.8.0"
  s.add_development_dependency "annotations", "~> 0.1.0"
end
