module ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision::Cloning
  def clone_complete?
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    raise MiqException::MiqProvisionError, "VM capture to template failed" if phase_context[:new_vm_ems_ref].nil?

    if source.template?
      association = :vms
    else
      association = :miq_templates
    end
    target = InventoryRefresh::Target.new(:manager     => source.ext_management_system,
                                          :association => association,
                                          :manager_ref => {:ems_ref => phase_context[:new_vm_ems_ref]})
    EmsRefresh.queue_refresh(target)
    true
  end

  def find_destination_in_vmdb(ems_ref)
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    if source.template?
      ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar.find_by(:name => dest_name, :ems_ref => ems_ref)
    else
      ManageIQ::Providers::IbmPowerHmc::InfraManager::Template.find_by(:name => dest_name, :ems_ref => ems_ref)
    end
  end

  def prepare_for_clone_task
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    if source.template?
      {:name => dest_name, :target_sys_uuid => dest_host.ems_ref}
    else
      {:name => dest_name}
    end
  end

  def log_clone_options(_clone_options)
    if source.template?
      $ibm_power_hmc_log.info("Deploying template [#{source.name}] to LPAR [#{dest_name}] on host [#{dest_host.name}]")
    else
      $ibm_power_hmc_log.info("Capturing LPAR [#{source.name}] to template [#{dest_name}]")
    end
  end

  def start_clone(clone_options)
    $ibm_power_hmc_log.info("start_clone")
    if source.template?
      source.provision_lpar(clone_options[:name])
    else
      source.make_template(clone_options)
    end
  end
end
