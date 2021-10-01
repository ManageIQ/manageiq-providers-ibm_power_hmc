class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  def provider_object(connection = nil)
    # connection ||= ext_management_system.connect
    # connection.find_vm(ems_ref)
  end

  def raw_start
    $ibm_power_hmc_log.info("raw_start ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweron_lpar(ems_ref)
    end
  ensure
    connection.logoff
  end

  def raw_stop
    $ibm_power_hmc_log.info("raw_stop ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, {"operation" => "shutdown"})
    end
  ensure
    connection.logoff
  end

  def raw_shutdown_guest
    # Damien: check rmc_status first!
    $ibm_power_hmc_log.info("raw_shutdown_guest ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, {"operation" => "osshutdown"})
    end
  ensure
    connection.logoff
  end

  def raw_reboot_guest
    # Damien: check rmc_status first!
    $ibm_power_hmc_log.info("raw_reboot_guest ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, {"operation" => "osshutdown", "restart" => "true"})
    end
  ensure
    connection.logoff
  end

  def raw_reset
    $ibm_power_hmc_log.info("raw_reset ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, {"operation" => "shutdown", "restart" => "true", "immediate" => "true"})
    end
  ensure
    connection.logoff
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
end
