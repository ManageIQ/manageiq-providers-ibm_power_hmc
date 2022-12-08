class ManageIQ::Providers::IbmPowerHmc::Inventory::Persister::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Persister
  def initialize_inventory_collections
    add_collection(infra, :hosts)
    add_collection(infra, :vms)
    add_collection(infra, :host_operating_systems)
    add_collection(infra, :host_hardwares)
    add_collection(infra, :host_guest_devices)
    add_collection(infra, :hardwares)
    add_collection(infra, :miq_templates)
    add_collection(infra, :host_virtual_switches)
    add_collection(infra, :host_switches)
    add_collection(infra, :operating_systems)
    add_collection(infra, :guest_devices)
    add_collection(infra, :lans, :secondary_refs => {:by_tag => %i[switch tag]})
    add_collection(infra, :host_virtual_lans)
    add_collection(infra, :storages)
    add_collection(infra, :disks)
    add_collection(infra, :networks)
    add_collection(infra, :vms_and_templates_advanced_settings) do |builder|
      builder.add_properties(
        :manager_ref                  => %i[resource name],
        :model_class                  => ::AdvancedSetting,
        :parent_inventory_collections => %i[vms]
      )
    end
    add_collection(infra, :hosts_advanced_settings) do |builder|
      builder.add_properties(
        :manager_ref                  => %i[resource name],
        :model_class                  => ::AdvancedSetting,
        :parent_inventory_collections => %i[hosts]
      )
    end
    add_collection(infra, :resource_pools)
    add_collection(infra, :vm_resource_pools)
    add_collection(infra, :parent_blue_folders)
    add_collection(infra, :vm_and_template_labels)
    add_collection(infra, :iso_images)
  end
end
