class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios < ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.vios(ems_ref)
  end

  def poweron(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweron_vios(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering on VIOS #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end

  def poweroff(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweroff_vios(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering off VIOS #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end
end
