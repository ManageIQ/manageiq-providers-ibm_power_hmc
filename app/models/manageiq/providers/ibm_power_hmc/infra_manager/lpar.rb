class ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar < ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm
  supports :rename

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.lpar(ems_ref)
  end

  def poweron(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweron_lpar(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering on LPAR #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end

  def poweroff(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweroff_lpar(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering off LPAR #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end

  def raw_rename(new_name)
    ext_management_system.with_provider_connection do |connection|
      connection.rename_lpar(ems_ref, new_name)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error renaming LPAR #{ems_ref} to #{new_name}: #{e}")
      raise
    end
  end

  def make_template(template_name)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} ems_ref #{ems_ref} template_name #{template_name}")
    ext_management_system.with_provider_connection do |connection|
      host_uuid = connection.lpar(ems_ref).sys_uuid
      connection.capture_lpar(ems_ref, host_uuid, template_name)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error creating template #{template_name} from LPAR #{ems_ref}: #{e}")
      raise
    end
  end
end
