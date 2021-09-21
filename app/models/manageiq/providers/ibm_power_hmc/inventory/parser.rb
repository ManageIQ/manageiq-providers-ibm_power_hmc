class ManageIQ::Providers::IbmPowerHmc::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :InfraManager
  require_nested :TargetCollection
end
