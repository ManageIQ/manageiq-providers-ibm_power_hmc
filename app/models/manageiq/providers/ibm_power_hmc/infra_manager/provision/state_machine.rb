module ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision::StateMachine
  def create_destination
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    signal :determine_placement
  end

  def determine_placement
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    signal :prepare_provision
  end

  def start_clone_task
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    update_and_notify_parent(:message => "Starting Clone of #{clone_direction}")

    log_clone_options(phase_context[:clone_options])
    phase_context[:new_vm_ems_ref] = start_clone(phase_context[:clone_options])
    phase_context.delete(:clone_options)

    signal :poll_clone_complete
  end

  def poll_clone_complete
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    update_and_notify_parent(:message => "Waiting for clone of #{clone_direction}")

    if clone_complete?
      signal :poll_destination_in_vmdb
    else
      requeue_phase
    end
  end

  def customize_destination
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    signal :post_provision
  end

  def autostart_destination
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    super
  end
end
