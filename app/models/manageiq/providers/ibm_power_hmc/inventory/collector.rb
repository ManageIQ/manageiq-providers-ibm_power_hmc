class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector < ManageIQ::Providers::Inventory::Collector
  require_nested :InfraManager
  require_nested :TargetCollection
end
