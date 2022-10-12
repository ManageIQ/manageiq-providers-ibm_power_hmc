class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  include ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCaptureMixin

  virtual_delegate :hmc_managed, :to => :host, :prefix => true, :allow_nil => true, :type => :boolean

  supports :control do
    unsupported_reason_add(:control, _("Host is not HMC-managed")) unless host_hmc_managed
  end

  supports :rename do
    unsupported_reason_add(:rename, _("Host is not HMC-managed")) unless host_hmc_managed
  end

  supports :native_console do
    reason ||= _("VM Console not supported because VM is orphaned") if orphaned?
    reason ||= _("VM Console not supported because VM is archived") if archived?
    unsupported_reason_add(:native_console, reason) if reason
  end

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

  def raw_rename(new_name)
    modify_attrs(:name => new_name)
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

  def collect_samples(_start_time, _end_time)
    raise StandardError, "Must be implemented in a subclass"
  end

  def process_samples(_counters, _samples)
    raise StandardError, "Must be implemented in a subclass"
  end

  # Override base class values to display performance data that's available
  def cpu_mhz_available?
    false
  end

  def cpu_percent_available?
    true
  end

  private

  def modify_attrs(attrs = {})
    ext_management_system.with_provider_connection do |connection|
      connection.modify_object do
        provider_object(connection).tap do |obj|
          attrs.each do |key, value|
            obj.send("#{key}=", value)
          end
        end
      end
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error setting attributes #{attrs} for partition #{ems_ref}: #{e}")
      raise
    end
  end
end
