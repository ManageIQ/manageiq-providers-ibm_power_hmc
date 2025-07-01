if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

Dir[Rails.root.join("spec/shared/**/*.rb")].sort.each { |f| require f }
Dir[File.join(__dir__, "support/**/*.rb")].sort.each { |f| require f }

require "manageiq/providers/ibm_power_hmc"

def sanitizer(interaction)
  # Mask API session token in recorded file even though the logoff invalidates it.
  interaction.request.headers["X-Api-Session"] = "xxx" if interaction.request.headers.key?("X-Api-Session")
  if interaction.request.uri.match?("rest/api/web/Logon")
    interaction.response.body.gsub!(/<X-API-Session[^>]*>[^<]*<\/X-API-Session>/, "<X-API-Session>xxx</X-API-Session>")
  elsif interaction.request.uri.match?("rest/api/templates")
    interaction.request.body.gsub!(/<K_X_API_SESSION_MEMENTO[^>]*>[^<]*<\/K_X_API_SESSION_MEMENTO>/, "<K_X_API_SESSION_MEMENTO>xxx</K_X_API_SESSION_MEMENTO>")
  end

  # Remove transient headers.
  resp_headers = interaction.response.headers
  %w[X-Transaction-Id X-Transactionrecord-Uuid Set-Cookie Date Last-Modified].each do |header|
    resp_headers.delete(header) if resp_headers.key?(header)
  end

  # Replace SSH key data.
  if interaction.request.uri.match?("ManagementConsole")
    interaction.response.body.gsub!(/<PublicSSHKeyValue[^>]*>[^<]*<\/PublicSSHKeyValue>/, "<PublicSSHKeyValue/>")
    interaction.response.body.gsub!(/<AuthorizedKey[^>]*>[^<]*<\/AuthorizedKey>/, "<AuthorizedKey/>")
  end

  interaction
end

VCR.configure do |config|
  config.ignore_hosts('codeclimate.com') if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::IbmPowerHmc::Engine.root, 'spec/vcr_cassettes')
  config.hook_into(:webmock)
  config.configure_rspec_metadata! # Auto-detects the cassette name based on the example's full description

  config.before_record do |i|
    sanitizer(i)
  end

  VcrSecrets.define_all_cassette_placeholders(config, :ibm_power_hmc)
end
