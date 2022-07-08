module ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision::Cloning
  def clone_complete?
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    raise MiqException::MiqProvisionError, "VM capture to template failed" if phase_context[:new_vm_ems_ref].nil?

    association = source.template? ? :vms : :miq_templates
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
      {
        :name                => dest_name,
        :host_id             => get_option(:placement_host_name),
        :vlan                => get_option(:vlan)
      }
    else
      {
        :name => dest_name
      }
    end
  end

  def log_clone_options(clone_options)
    if source.template?
      $ibm_power_hmc_log.info("Provisioning [#{source.name}] to [#{clone_options[:name]}]")
      $ibm_power_hmc_log.info("Source Template:            [#{source.name}]")
      $ibm_power_hmc_log.info("Destination VM Name:        [#{clone_options[:name]}]")
      $ibm_power_hmc_log.info("Destination Host:           [#{clone_options[:host_id]}]")
      $ibm_power_hmc_log.info("Destination Vlan:           [#{clone_options[:vlan]}]")
    else
      $ibm_power_hmc_log.info("Capturing LPAR [#{source.name}] to template [#{dest_name}]")
    end
  end

  def start_clone(clone_options)
    $ibm_power_hmc_log.info("start_clone")
    if source.template?
      source.provision_lpar(clone_options)
    else
      source.make_template(clone_options)
    end
  end
end
