# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'rich-text/version'

Gem::Specification.new do |spec|
  spec.name          = "rich-text"
  spec.version       = RichText::VERSION
  spec.authors       = ["Blake Thomson"]
  spec.email         = ["thomsbg@gmail.com"]

  spec.summary       = %q{A ruby wrapper and utilities for rich text JSON documents.}
  spec.homepage      = "https://github.com/voxmedia/rich-text-ruby"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "diff-lcs", "~> 1.2.5"
  spec.add_dependency "activesupport", ">= 3.0.0"
  # spec.add_dependency "nokogiri", ">= 1.0.0"
  spec.add_development_dependency "bundler", "~> 1.13"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "yard"
end
