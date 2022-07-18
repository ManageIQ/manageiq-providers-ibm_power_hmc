FactoryBot.define do
  factory :ibm_power_hmc_miq_provision,
          :parent => :miq_provision,
          :class  => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision",
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager/provision"]       
end