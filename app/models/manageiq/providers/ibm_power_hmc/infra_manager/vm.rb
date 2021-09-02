class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    #connection.find_vm(ems_ref)
  end

  def raw_start
    $log.info("Damien: raw_start ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweron_lpar(ems_ref)
    end
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "running") # Damien: "starting"
  end

  def raw_stop
    $log.info("Damien: raw_stop ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, { "operation" => "shutdown" })
    end
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "not activated")
  end

  def raw_shutdown_guest
    # Damien: check rmc_status first!
    $log.info("Damien: raw_shutdown_guest ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, { "operation" => "osshutdown" })
    end
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "not activated")
  end

  def raw_reboot_guest
    # Damien: check rmc_status first!
    $log.info("Damien: raw_reboot_guest ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, { "operation" => "osshutdown", "restart" => "true" })
    end
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "running")
  end

  def raw_reset
    $log.info("Damien: raw_reset ems_ref=#{ems_ref}")
    ext_management_system.with_provider_connection do |connection|
      # Damien: check VIOS or LPAR from description?
      connection.poweroff_lpar(ems_ref, { "operation" => "shutdown", "restart" => "true", "immediate" => "true" })
    end
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "running")
  end

  def raw_destroy
  end

  def raw_suspend
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "suspended")
  end

  def raw_rename
  end

  POWER_STATES = {
    "running"       => "on",
    "open firmware" => "on",
    "not activated" => "off",
    "not available" => "unknown",
    # Damien: TBD
  }.freeze

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state] || "unknown"
  end
end
