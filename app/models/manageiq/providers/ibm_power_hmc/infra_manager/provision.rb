class ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision < MiqProvision
  include_concern 'Cloning'
  include_concern 'StateMachine'
  def destination_type
    "Vm"
  end
end
