FactoryBot.define do
  factory :ems_ibm_power_hmc_infra,
          :aliases => ["manageiq/providers/ibm_power_hmc/infra_manager"],
          :class   => "ManageIQ::Providers::IbmPowerHmc::InfraManager",
          :parent  => :ems_infra
end
