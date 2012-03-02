# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "hercule/version"

Gem::Specification.new do |s|
  s.name        = "hercule"
  s.version     = Hercule::VERSION
  s.authors     = ["Dylan Paris"]
  s.email       = ["dylan.paris+github@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Document Classification Library}
  s.description = %q{A document classification library using Support Vector Machines}

  s.rubyforge_project = "hercule"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  #s.add_runtime_dependency "rb-libsvm"
  s.add_runtime_dependency "gtokenizer"
  s.add_runtime_dependency "fast-stemmer"
  s.add_runtime_dependency "uuid"
  s.add_runtime_dependency "libsvm-ruby-swig"
  #s.add_runtime_dependency "fselector"

  # s.add_development_dependency "rspec"
end
