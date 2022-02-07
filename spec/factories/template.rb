FactoryBot.define do
  factory :ibm_power_hmc_template,
          :aliases => ["manageiq/providers/infra_manager/template"],
          :class   => "ManageIQ::Providers::InfraManager::Template",
          :parent  => :template_infra
end
