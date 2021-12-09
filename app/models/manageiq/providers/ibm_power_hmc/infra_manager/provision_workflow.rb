class ManageIQ::Providers::IbmPowerHmc::InfraManager::ProvisionWorkflow < ManageIQ::Providers::InfraManager::ProvisionWorkflow
  def dialog_name_from_automate(message = 'get_dialog_name')
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    super(message, {'platform' => 'ibm_power_hmc'})
  end
end
