module ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision::Cloning
  def clone_complete?
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    raise MiqException::MiqProvisionError, "[#{source.name}] to [#{destination_type}] #{request_type} failed" if phase_context[:new_vm_ems_ref].nil?

    association = destination_type.eql?("Vm") ? :vms : :miq_templates
    target = InventoryRefresh::Target.new(:manager     => source.ext_management_system,
                                          :association => association,
                                          :manager_ref => {:ems_ref => phase_context[:new_vm_ems_ref]})
    EmsRefresh.queue_refresh(target)
    true
  end

  def find_destination_in_vmdb(ems_ref)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} #{destination_type} #{ems_ref}")
    if destination_type.eql?("Vm")
      source.ext_management_system.vms.find_by(:ems_ref => ems_ref)
    else
      source.ext_management_system.miq_templates.find_by(:ems_ref => ems_ref)
    end
  end

  def prepare_for_clone_task
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    if destination_type.eql?("Vm")
      {
        :name    => dest_name,
        :host_id => get_option(:placement_host_name),
        :vlan    => get_option(:vlan)
      }
    else
      {
        :name => dest_name
      }
    end
  end

  def log_clone_options(clone_options)
    $ibm_power_hmc_log.info("#{request_type} [#{source.name}] to [#{clone_options[:name]}]")
    if destination_type.eql?("Vm")
      $ibm_power_hmc_log.info("Destination Host: [#{clone_options[:host_id]}]")
      $ibm_power_hmc_log.info("Destination Vlan: [#{clone_options[:vlan]}]")
    end
  end

  def start_clone(clone_options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    source.do_request(request_type, clone_options)
  end
end
