class ManageIQ::Providers::IbmPowerHmc::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  require_nested :InfraManager

  def initialize_inventory_collections
    add_collection(infra, :hosts)
    add_collection(infra, :vms)
  end
end
