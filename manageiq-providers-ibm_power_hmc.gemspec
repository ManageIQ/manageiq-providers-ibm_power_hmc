# coding: utf-8

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'manageiq/providers/ibm_power_hmc/version'

Gem::Specification.new do |spec|
  spec.name          = "manageiq-providers-ibm_power_hmc"
  spec.version       = ManageIQ::Providers::IbmPowerHmc::VERSION
  spec.authors       = ["ManageIQ Authors"]

  spec.summary       = "ManageIQ plugin for the IBM Power HMC provider."
  spec.description   = "ManageIQ plugin for the IBM Power HMC provider."
  spec.homepage      = "https://github.com/ManageIQ/manageiq-providers-ibm_power_hmc"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ibm_power_hmc", "~> 0.8"

  spec.add_development_dependency "manageiq-style"
  spec.add_development_dependency "simplecov"
end
