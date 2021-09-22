module ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser
  def self.event_to_hash(event, ems_id)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} #{event}")

    event_hash = {
      :event_type => event.type,
      :source     => 'IBM_POWER_HMC',
      :ems_ref    => event.id,
      :timestamp  => event.published,
      # Serialize IbmPowerHmc::Event
      :full_data  => {:data => event.data, :detail => event.detail},
      :ems_id     => ems_id
    }
    event_hash
  end
end
