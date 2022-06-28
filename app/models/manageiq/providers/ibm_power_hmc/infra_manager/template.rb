class ManageIQ::Providers::IbmPowerHmc::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  supports :provisioning

  def provision_lpar(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} lpar name #{options[:name]}")
    ext_management_system.with_provider_connection do |connection|
      connection.template_provision(ems_ref, options[:target_sys_uuid], {
        :lpar_name => options[:name],
        :lpar_id   => nil
      })
    rescue IbmPowerHmc::Connection::HttpError, IbmPowerHmc::HmcJob::JobFailed => e
      $ibm_power_hmc_log.error("error creating LPAR #{options[:name]} from template #{name}: #{e}")
      raise
    end
  end
end
