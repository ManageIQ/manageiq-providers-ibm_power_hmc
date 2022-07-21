class ManageIQ::Providers::IbmPowerHmc::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  supports :provisioning
  supports :clone

  def provision_lpar(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} lpar name #{options[:name]}")
    host = Host.find(options[:host_id])
    vlan = host.lans.find_by(:name => options[:vlan])
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

  def make_clone(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} copy name #{options[:name]}")
    ext_management_system.with_provider_connection do |connection|
      connection.template_copy(ems_ref, options[:name]).uuid
    rescue IbmPowerHmc::Connection::HttpError, IbmPowerHmc::HmcJob::JobFailed => e
      $ibm_power_hmc_log.error("error copying template #{options[:name]} to #{name}: #{e}")
      raise
    end
  end
end
