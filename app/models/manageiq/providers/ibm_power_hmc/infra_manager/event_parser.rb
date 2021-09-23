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

    case event.type
    when /.*_URI/
      uri = URI(event.data)
      elems = uri.path.split('/')
      type, uuid = elems[-2], elems[-1]
      case type
      when "ManagedSystem"
        event_hash[:host_ems_ref] = uuid
      when "LogicalPartition", "VirtualIOServer"
        event_hash[:vm_ems_ref] = uuid
        # Check if the URI also contains /ManagedSystem/{uuid}/
        if elems.length >= 4 && elems[-4] == "ManagedSystem"
          event_hash[:host_ems_ref] = elems[-3]
        end
      end
    end

    event_hash
  end
end
