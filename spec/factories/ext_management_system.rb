FactoryBot.define do
  factory :ems_ibm_power_hmc_infra,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager",
          :parent  => :ems_infra

  factory :ems_ibm_power_hmc_infra_with_authentication, :parent => :ems_ibm_power_hmc_infra do
    zone do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      zone
    end

    endpoints do
      [
        FactoryBot.create(:endpoint,
          :role     => "default",
          :hostname => Rails.application.secrets.ibm_power_hmc[:hostname],
          :port     => 12_443
        )
      ]
    end

    after(:create) do |ems|
      ems.authentications << FactoryBot.create(:authentication,
        :userid   => Rails.application.secrets.ibm_power_hmc[:username],
        :password => Rails.application.secrets.ibm_power_hmc[:password]
      )
    end
  end
end
