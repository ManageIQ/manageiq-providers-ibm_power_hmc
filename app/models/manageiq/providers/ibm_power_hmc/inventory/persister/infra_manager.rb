class ManageIQ::Providers::IbmPowerHmc::Inventory::Persister::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Persister
  def initialize_inventory_collections
    add_collection(infra, :hosts)
    add_collection(infra, :vms)
    add_collection(infra, :host_operating_systems)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :hardwares)
    add_collection(infra, :miq_templates) # required by hardwares.vm_or_template
    add_collection(infra, :host_virtual_switches)
    add_collection(infra, :host_switches)
    add_collection(infra, :operating_systems)
    add_collection(infra, :guest_devices)
    add_collection(infra, :lans)
    add_collection(infra, :host_virtual_lans)
    add_collection(infra, :vms_and_templates_advanced_settings) do |builder|
      builder.add_properties(
        :manager_ref                  => %i[resource name],
        :model_class                  => ::AdvancedSetting,
        :parent_inventory_collections => %i[vms]
      )
    end
  end
end
