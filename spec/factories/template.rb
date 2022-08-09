FactoryBot.define do
  factory :ibm_power_hmc_template,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager/template"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Template",
          :parent  => :template_infra
end
