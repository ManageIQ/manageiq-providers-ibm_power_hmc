class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  def provider_object(_connection = nil)
    raise StandardError, "Must be implemented in a subclass"
  end

  def raw_start
    poweron
  end

  def raw_stop
    poweroff("operation" => "shutdown")
  end

  def raw_shutdown_guest
    poweroff("operation" => "osshutdown")
  end

  def raw_reboot_guest
    poweroff("operation" => "osshutdown", "restart" => "true")
  end

  def raw_reset
    poweroff("operation" => "shutdown", "restart" => "true", "immediate" => "true")
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

  def poweron(_params = {})
    raise StandardError, "Must be implemented in a subclass"
  end

  def poweroff(_params = {})
    raise StandardError, "Must be implemented in a subclass"
  end
end
