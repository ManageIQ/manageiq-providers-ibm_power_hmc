class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    if vios?
      connection.vios(ems_ref)
    else
      connection.lpar(ems_ref)
    end
  end

  def raw_start
    $ibm_power_hmc_log.info("raw_start ems_ref=#{ems_ref}")
    power
  end

  def raw_stop
    $ibm_power_hmc_log.info("raw_stop ems_ref=#{ems_ref}")
    power({"operation" => "shutdown"})
  end

  def raw_shutdown_guest
    $ibm_power_hmc_log.info("raw_shutdown_guest ems_ref=#{ems_ref}")
    power({"operation" => "osshutdown"})
  end

  def raw_reboot_guest
    $ibm_power_hmc_log.info("raw_reboot_guest ems_ref=#{ems_ref}")
    power({"operation" => "osshutdown", "restart" => "true"})
  end

  def raw_reset
    $ibm_power_hmc_log.info("raw_reset ems_ref=#{ems_ref}")
    power({"operation" => "shutdown", "restart" => "true", "immediate" => "true"})
  end

  def raw_destroy
  end

  def raw_suspend
  end

  def raw_rename
  end

  # See LogicalPartitionState.Enum (/rest/api/web/schema/inc/Enumerations.xsd)
  POWER_STATES = {
    "error"                => "unknown",
    "not activated"        => "off",
    "not available"        => "unknown",
    "open firmware"        => "on",
    "running"              => "on",
    "shutting down"        => "on",
    "starting"             => "on",
    "migrating not active" => "on",
    "migrating running"    => "on",
    "hardware discovery"   => "unknown",
    "suspended"            => "unknown",
    "suspending"           => "unknown",
    "resuming"             => "unknown",
    "Unknown"              => "unknown"
  }.freeze

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || "unknown"
  end

  private

  def vios?
    description == "Virtual IO Server"
  end

  def power(params = {})
    ext_management_system.with_provider_connection do |connection|
      if params.key?("operation")
        if vios?
          connection.poweroff_vios(ems_ref, params)
        else
          connection.poweroff_lpar(ems_ref, params)
        end
      elsif vios?
        connection.poweron_vios(ems_ref, params)
      else
        connection.poweron_lpar(ems_ref, params)
      end
    end
  rescue IbmPowerHmc::Connection::HttpError => e
    $ibm_power_hmc_log.error("error changing power state of #{ems_ref} with params=#{params}: #{e}")
  end
end
