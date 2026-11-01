module ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision::StateMachine
  ERROR_DETAIL_MAX_LENGTH = 2048

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

  # ManageIQ cuts a task's message to 255 characters, which can drop the reason the HMC gave. Before it does,
  # keep the full text in options[:error_detail] so a client (e.g. the PMC MCP server) can read it back from
  # the request task. Only for template provisioning (request_type 'template'). The task's message, state and
  # status are left exactly as ManageIQ sets them.
  def provision_error
    store_error_detail
    super
  end

  private

  # Runs in the terminal error phase, where ManageIQ does not recover from an error: it must never raise.
  # Read before super, because provision_error deletes these phase_context keys.
  def store_error_detail
    return unless request_type == 'template'

    detail = phase_context[:error_message].presence
    detail ||= "[#{phase_context[:exception_class]}]: #{phase_context[:exception_message]}" if phase_context[:exception_message].present?
    return if detail.blank?

    original = options
    update!(:options => original.merge(:error_detail => detail.to_s[0, ERROR_DETAIL_MAX_LENGTH]))
  rescue StandardError => err
    self.options = original if original # drop the unsaved change so the update in super is not affected
    begin
      $ibm_power_hmc_log.warn("#{self.class}#store_error_detail could not store error_detail: #{err.class}")
    rescue StandardError
      nil
    end
  end
end
