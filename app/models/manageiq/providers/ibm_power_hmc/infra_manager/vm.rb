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
    "shutting down"        => "powering_down",
    "starting"             => "powering_up",
    "migrating not active" => "off",
    "migrating running"    => "on",
    "hardware discovery"   => "powering_up",
    "suspended"            => "suspended",
    "suspending"           => "suspended",
    "resuming"             => "powering_up",
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

  def make_template(_clone_options)
    raise StandardError, "Must be implemented in a subclass"
  end

  def capture_metrics(counters, start_time = nil, end_time = nil)
    samples = collect_samples(start_time, end_time)
    process_samples(counters, samples)
  end

  private

  def collect_samples(_start_time, _end_time)
    raise StandardError, "Must be implemented in a subclass"
  end

  def process_samples(_counters, _samples)
    raise StandardError, "Must be implemented in a subclass"
  end
end
