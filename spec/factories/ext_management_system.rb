FactoryBot.define do
  factory :ems_ibm_power_hmc_infra,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager",
          :parent  => :ems_infra

  factory :ems_ibm_power_hmc_infra_with_authentication, :parent => :ems_ibm_power_hmc_infra do
    username = Rails.application.secrets.ibm_power_hmc[:username]
    password = Rails.application.secrets.ibm_power_hmc[:password]
    hostname = Rails.application.secrets.ibm_power_hmc[:hostname]

    zone do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      zone
    end

    endpoints do
      [FactoryBot.create(:endpoint, :role => "default", :hostname => hostname, :port => 12_443)]
    end

    after(:create) do |ems|
      ems.authentications << FactoryBot.create(:authentication, :userid => username, :password => password)
    end
  end
end
