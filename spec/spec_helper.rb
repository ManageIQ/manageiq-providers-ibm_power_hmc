if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

Dir[Rails.root.join("spec/shared/**/*.rb")].sort.each { |f| require f }
Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |f| require f }

require "manageiq-providers-ibm_power_hmc"

VCR.configure do |config|
  # Configure VCR to use rspec metadata.
  config.hook_into(:webmock)
  config.configure_rspec_metadata!

  config.ignore_hosts('codeclimate.com') if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::IbmPowerHmc::Engine.root, 'spec/vcr_cassettes')

  secrets = Rails.application.secrets
  secrets.ibm_power_hmc.each_key do |secret|
    config.define_cassette_placeholder(secrets.ibm_power_hmc_defaults[secret]) { secrets.ibm_power_hmc[secret] }
  end
end
