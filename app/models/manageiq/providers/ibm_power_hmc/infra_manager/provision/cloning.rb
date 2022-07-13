module ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision::Cloning
  def log_clone_options(clone_options)
    send("#{request_type}_log_clone_options", clone_options)
  end

  def start_clone(clone_options)
    send("#{request_type}_start_clone", clone_options)
  end

  def clone_complete?
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    raise MiqException::MiqProvisionError, "#{request_type} to #{destination_type} capture/provision failed" if phase_context[:new_vm_ems_ref].nil?

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

  def template_log_clone_options(clone_options)
    $ibm_power_hmc_log.info("Provisioning [#{source.name}] to [#{clone_options[:name]}]")
    $ibm_power_hmc_log.info("Source Template:     [#{source.name}]")
    $ibm_power_hmc_log.info("Destination VM Name: [#{clone_options[:name]}]")
    $ibm_power_hmc_log.info("Destination Host:    [#{clone_options[:host_id]}]")
    $ibm_power_hmc_log.info("Destination Vlan:    [#{clone_options[:vlan]}]")
  end

  def template_start_clone(clone_options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    source.provision_lpar(clone_options)
  end

  def clone_to_vm_log_clone_options(clone_options)
    $ibm_power_hmc_log.info("Cloning #{destination_type} [#{source.name}] to [#{clone_options[:name]}]")
  end

  def clone_to_vm_start_clone(clone_options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    source.make_clone(clone_options)
  end

  def clone_to_template_log_clone_options(clone_options)
    $ibm_power_hmc_log.info("Capturing LPAR [#{source.name}] to template [#{clone_options[:name]}]")
  end

  def clone_to_template_start_clone(clone_options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    source.make_template(clone_options)
  end
end
