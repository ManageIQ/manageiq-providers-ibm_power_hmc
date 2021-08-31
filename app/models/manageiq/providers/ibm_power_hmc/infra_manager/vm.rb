class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm < ManageIQ::Providers::InfraManager::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    #connection.find_vm(ems_ref)
  end

  def raw_start
    with_provider_object(&:start)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "on")
  end

  def raw_stop
    with_provider_object(&:stop)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "off")
  end

  def raw_pause
    with_provider_object(&:pause)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "paused")
  end

  def raw_suspend
    with_provider_object(&:suspend)
    # Temporarily update state for quick UI response until refresh comes along
    update!(:raw_power_state => "suspended")
  end

  POWER_STATES = {
    "running"       => "on",
    "open firmware" => "on",
    "not activated" => "off",
    "not available" => "unknown",
  }.freeze

  def self.calculate_power_state(raw_power_state)
    POWER_STATES[raw_power_state.to_s] || "terminated"
  end
end
