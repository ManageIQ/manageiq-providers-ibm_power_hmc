class ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision < MiqProvision
  include_concern 'Cloning'
  include_concern 'StateMachine'
  def destination_type
    "Vm"
  end

  def with_provider_destination
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    return if destination.nil?
    destination.with_provider_object { |obj| yield obj }
  end
end
