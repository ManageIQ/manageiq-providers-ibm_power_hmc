class ManageIQ::Providers::IbmPowerHmc::Inventory::Persister::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Persister
  def initialize_inventory_collections
    add_collection(infra, :hosts)
    add_collection(infra, :vms)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :hardwares)
    add_collection(infra, :miq_templates) # required by hardwares.vm_or_template
  end
end
