module ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser
  def self.event_to_hash(event, ems_id)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} #{event.to_s}")

    event_hash = {
      :event_type => event.type,
      :source     => 'IBM_POWER_HMC',
      :ems_ref    => event.id,
      :timestamp  => event.published,
      :full_data  => event,
      :ems_id     => ems_id
    }
    case event.type
    when /.*_URI/
      uri = URI(event.data)
      elems = uri.path.split('/')
      uuid = elems[-1]
      type = elems[-2]
      if type == "LogicalPartition"
        event_hash[:vm_ems_ref] = uuid
      end
    end

    event_hash
  end
end
