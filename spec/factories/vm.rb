FactoryBot.define do
  factory :ibm_power_hmc_lpar,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager/lpar"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar",
          :parent  => :vm_infra
end
