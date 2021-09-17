class ManageIQ::Providers::IbmPowerHmc::Inventory::Persister::TargetCollection < ManageIQ::Providers::IbmPowerHmc::Inventory::Persister
  def targeted?
    true
  end

  def initialize_inventory_collections
  end
end
