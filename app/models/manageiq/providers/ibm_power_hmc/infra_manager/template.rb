class ManageIQ::Providers::IbmPowerHmc::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  supports :provisioning

  def get_host(host_id)
    ManageIQ::Providers::IbmPowerHmc::InfraManager::Host.find(host_id)
  end

  def get_vlan(host, vlan_name)
    Lan.find_by(:ems_ref => host.ems_ref, :name => vlan_name)
  end

  def provision_lpar(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} lpar name #{options[:name]}")
    host = get_host(options[:host_id])
    vlan = get_vlan(host, options[:vlan])
    ext_management_system.with_provider_connection do |connection|
      connection.template_provision(
        ems_ref,
        host.ems_ref,
        {
          :lpar_name => options[:name],
          :lpar_id   => nil,
          :vlans     => [{:name => vlan.name, :vlan_id => vlan.tag, :switch => vlan.switch.name}]
        }
      )
    rescue IbmPowerHmc::Connection::HttpError, IbmPowerHmc::HmcJob::JobFailed => e
      $ibm_power_hmc_log.error("error creating LPAR #{options[:name]} from template #{name}: #{e}")
      raise
    end
  end
end
