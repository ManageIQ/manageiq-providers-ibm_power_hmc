module ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision::Cloning
  def clone_complete?
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    raise MiqException::MiqProvisionError, "VM capture to template failed" if phase_context[:new_vm_ems_ref].nil?
    target = InventoryRefresh::Target.new(:manager     => source.ext_management_system,
                                          :association => :miq_templates,
                                          :manager_ref => {:ems_ref => phase_context[:new_vm_ems_ref]})
    EmsRefresh.queue_refresh(target)
    true
  end

  def find_destination_in_vmdb(ems_ref)
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    ManageIQ::Providers::IbmPowerHmc::InfraManager::Template.find_by(:name => dest_name, :ems_ref => ems_ref)
  end

  def prepare_for_clone_task
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    clone_options = { :name => dest_name }
  end

  def log_clone_options(clone_options)
    $ibm_power_hmc_log.info("Provisioning [#{source.name}] to [#{dest_name}]")
  end

  def start_clone(clone_options)
    $ibm_power_hmc_log.info("start_clone")
    source.make_template(clone_options[:name])
  end
end
