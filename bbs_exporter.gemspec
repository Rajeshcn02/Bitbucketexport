# coding: utf-8
# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bbs_exporter/version"

Gem::Specification.new do |spec|
  spec.name          = "bbs_exporter"
  spec.version       = BbsExporter::VERSION
  spec.authors       = ["Kyle Macey", "Matthew Duff", "Maxwell Pray", "Daniel Perez", "Michael Johnson"]
  spec.email         = ["kylemacey@github.com", "mattcantstop@github.com", "synthead@github.com", "dpmex4527@github.com", "migarjo@github.com"]

  spec.summary       = "Exports Bitbucket Server data as ghe-migrator archives."
  spec.homepage      = "https://github.com/github/bbs-exporter"

  spec.files         = %w(README.md CODE_OF_CONDUCT.md Rakefile bbs_exporter.gemspec)
  spec.files         += Dir.glob("{bin,exe,lib,script}/**/*")
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.4.0"

  spec.add_dependency "activemodel",        "~> 6.0.0"
  spec.add_dependency "activesupport",      "~> 6.0.0"
  spec.add_dependency "addressable",        "~> 2.7.0"
  spec.add_dependency "climate_control",    "~> 0.2.0"
  spec.add_dependency "colorize",           "~> 0.8.1"
  spec.add_dependency "dotenv",             "~> 2.7.5"
  spec.add_dependency "excon",              "~> 0.67.0"
  spec.add_dependency "faraday",            "~> 0.17.0"
  spec.add_dependency "faraday-http-cache", "~> 2.0.0"
  spec.add_dependency "faraday_middleware", "~> 0.13.1"
  spec.add_dependency "git",                "~> 1.5.0"
  spec.add_dependency "mime-types",         "~> 3.3"
  spec.add_dependency "posix-spawn",        "~> 0.3.13"
  spec.add_dependency "ruby-progressbar",   "~> 1.10.1"
  spec.add_dependency "ruby-terminfo",      "~> 0.1.1"
  spec.add_dependency "rugged",             "~> 0.28.3.1"
  spec.add_dependency "ssh-fingerprint",    "~> 0.0.3"

  spec.add_development_dependency "bundler",            "~> 2.0.2"
  spec.add_development_dependency "irb",                "~> 1.0.0"
  spec.add_development_dependency "pry-byebug",         "~> 3.7.0"
  spec.add_development_dependency "pry-rescue",         "~> 1.5.0"
  spec.add_development_dependency "pry-stack_explorer", "~> 0.4.9.3"
  spec.add_development_dependency "rake",               "~> 13.0.0"
  spec.add_development_dependency "redcarpet",          "~> 3.5.0"
  spec.add_development_dependency "rspec",              "~> 3.9.0"
  spec.add_development_dependency "rubocop-github",     "~> 0.13.0"
  spec.add_development_dependency "timecop",            "~> 0.9.1"
  spec.add_development_dependency "vcr",                "~> 5.0.0"
  spec.add_development_dependency "webmock",            "~> 3.7.6"
  spec.add_development_dependency "yard",               "~> 0.9.20"
end
