class ManageIQ::Providers::IbmPowerHmc::InfraManager::EventTargetParser
  attr_reader :ems_event

  def initialize(ems_event)
    @ems_event = ems_event
  end

  def elem(url)
    uri = URI(url)
    tokens = uri.path.split('/')
    elems = {
      :type => tokens[-2],
      :uuid => tokens[-1]
    }
    if tokens.length >= 4 && tokens[-4] == "ManagedSystem"
      elems[:manager_uuid] = tokens[-3]
    end
    elems
  end

  def parse
    target_collection = InventoryRefresh::TargetCollection.new(
      :manager => ems_event.ext_management_system,
      :event   => ems_event
    )

    raw_event = ems_event.full_data

    case ems_event.event_type
    when "MODIFY_URI", "ADD_URI", "DELETE_URI" # Damien: INVALID_URI?
      $ibm_power_hmc_log.info("#{self.class}##{__method__} #{ems_event.event_type} #{ems_event.full_data}")
      elems = elem(raw_event[:data])
      case elems[:type]
      when "ManagedSystem"
        elems[:assoc] = :hosts
        elems[:ems_ref] = elems[:uuid]
      when "LogicalPartition", "VirtualIOServer"
        # raw_event[:detail] contains information about the properties that
        # have changed (e.g. RMCState, PartitionName, PartitionState etc...)
        # This may be used to perform quick property REST API calls to the HMC
        # instead of querying the full LPAR data.
        elems[:assoc] = :vms
        elems[:ems_ref] = elems[:uuid]
      when "VirtualSwitch", "VirtualNetwork"
        if elems.has_key?(:manager_uuid)
          elems[:assoc] = :hosts
          elems[:ems_ref] = elems[:manager_uuid]
        end
      when "UserTask"
        elems.merge!(handle_usertask(raw_event[:usertask]))
      when "Cluster"
        elems[:assoc] = :storages
        elems[:ems_ref] = elems[:uuid]
      end

      if elems.has_key?(:assoc)
        $ibm_power_hmc_log.info("#{self.class}##{__method__} #{elems[:type]} uuid #{elems[:uuid]}")
        target_collection.add_target(
          :association => elems[:assoc],
          :manager_ref => {:ems_ref => elems[:ems_ref]}
        )
      end
    end

    # Return the set of targets from this event
    target_collection.targets
  end

  def handle_usertask(usertask)
    if usertask["status"].eql?("Completed")
      case usertask["key"]
      when "TEMPLATE_PARTITION_SAVE", "TEMPLATE_PARTITION_SAVE_AS", "TEMPLATE_PARTITION_CAPTURE"
        r = {:assoc => :miq_templates, :ems_ref => usertask['template_uuid']}
      when "TEMPLATE_DELETE"
        template = ManageIQ::Providers::InfraManager::Template.find_by(:ems_id => ems_event.ext_management_system.id, :name => usertask['labelParams'])
        unless template.nil?
          r = {:assoc => :miq_templates, :ems_ref => template.uid_ems}
        end
      end
    end
    r || {}
  end
end
