FactoryBot.define do
  factory :ibm_power_hmc_lpar,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager/lpar"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar",
          :parent  => :vm_infra
end

FactoryBot.define do
  factory :ibm_power_hmc_vios,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager/vios"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios",
          :parent  => :vm_infra
end
