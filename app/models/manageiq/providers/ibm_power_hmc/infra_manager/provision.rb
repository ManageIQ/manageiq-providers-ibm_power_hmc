class ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision < MiqProvision
  include_concern 'Cloning'
  include_concern 'StateMachine'

  VALID_REQUEST_TYPES = %w[clone_to_template clone_to_vm template].freeze
  validates :request_type, :inclusion => {:in => VALID_REQUEST_TYPES, :message => "should be one of: #{VALID_REQUEST_TYPES.join(', ')}"}

  def destination_type
    case request_type
    when 'template'          then "Vm"
    when 'clone_to_template' then "Template"
    when 'clone_to_vm'
      if source.template?
        "Template"
      else
        "Vm"
      end
    else ""
    end
  end
end
