FactoryBot.define do
  factory :ibm_power_hmc_host,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager/host"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Host",
          :parent  => :host
end
