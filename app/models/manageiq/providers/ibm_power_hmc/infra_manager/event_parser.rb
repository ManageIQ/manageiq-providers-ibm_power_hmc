module ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser
  def self.event_to_hash(event, ems_id)
    event_hash = {
      :event_type => event.type,
      :source     => 'IBM_POWER_HMC',
      :ems_ref    => event.id,
      :timestamp  => event.published,
      :message    => event.detail,
      # Serialize IbmPowerHmc::Event
      :full_data  => {:data => event.data, :detail => event.detail, :usertask => event.usertask},
      :ems_id     => ems_id
    }

    elems = URI(event.data).path.split('/')
    type, uuid = elems[-2], elems[-1]

    # Check if the URI also contains /ManagedSystem/{uuid}/
    if elems.length >= 4 && elems[-4] == "ManagedSystem"
      host_uuid = elems[-3]
    end

    case type
    when "ManagedSystem"
      event_hash[:host_ems_ref] = uuid
    when "LogicalPartition", "VirtualIOServer"
      event_hash[:vm_ems_ref]   = uuid
      event_hash[:host_ems_ref] = host_uuid unless host_uuid.nil?
    when "VirtualSwitch", "VirtualNetwork", "SharedProcessorPool"
      event_hash[:host_ems_ref] = host_uuid unless host_uuid.nil?
    when "UserTask"
      event_hash[:message] = event.usertask["key"]
    end

    event_hash
  end
end
