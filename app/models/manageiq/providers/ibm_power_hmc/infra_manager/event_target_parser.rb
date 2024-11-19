class ManageIQ::Providers::IbmPowerHmc::InfraManager::EventTargetParser
  attr_reader :ems_event

  NO_UUID_VALUE = "88888888-8888-8888-8888-888888888888" # Returned when no UUID assigned to LPAR

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
    new_targets = []

    ems       = ems_event.ext_management_system
    raw_event = ems_event.full_data

    case ems_event.event_type
    when "MODIFY_URI", "ADD_URI", "DELETE_URI" # Damien: INVALID_URI?
      $ibm_power_hmc_log.info("#{self.class}##{__method__} #{ems_event.event_type} #{ems_event.full_data}")
      elems = elem(raw_event[:data])
      case elems[:type]
      when "ManagedSystem"
        new_targets << {:assoc => :hosts, :ems_ref => elems[:uuid]}
      when "LogicalPartition", "VirtualIOServer"
        # raw_event[:detail] contains information about the properties that
        # have changed (e.g. RMCState, PartitionName, PartitionState etc...)
        # This may be used to perform quick property REST API calls to the HMC
        # instead of querying the full LPAR data.
        if elems[:uuid].eql?(NO_UUID_VALUE)
          $ibm_power_hmc_log.info("#{self.class}##{__method__} #{elems[:type]} Missing LPAR UUID.  Escalating to full refresh for EMS: [#{ems.name}], id: [#{ems.id}].")
          target_collection << ems
        else
          new_targets << {:assoc => :vms, :ems_ref => elems[:uuid]}
        end
      when "VirtualSwitch", "VirtualNetwork"
        if elems.key?(:manager_uuid)
          new_targets << {:assoc => :hosts, :ems_ref => elems[:manager_uuid]}
        end
      when "UserTask"
        new_targets.concat(handle_usertask(raw_event[:usertask]))
      when "Cluster"
        new_targets << {:assoc => :storages, :ems_ref => elems[:uuid]}
      when "SharedProcessorPool", "SharedMemoryPool"
        new_targets << {:assoc => :resource_pools, :ems_ref => "#{elems[:manager_uuid]}_#{elems[:uuid]}"}
      end

      new_targets.each do |t|
        $ibm_power_hmc_log.info("#{self.class}##{__method__} #{elems[:type]} uuid #{t[:ems_ref]}")
        target_collection.add_target(
          :association => t[:assoc],
          :manager_ref => {:ems_ref => t[:ems_ref]}
        )
      end
      target_collection
    end

    # Return the set of targets from this event
    target_collection.targets
  end

  def handle_usertask(usertask)
    return [] unless usertask["status"].eql?("Completed")

    case usertask["key"]
    when "TEMPLATE_PARTITION_SAVE", "TEMPLATE_PARTITION_SAVE_AS", "TEMPLATE_PARTITION_CAPTURE"
      handle_usertask_template_save(usertask)
    when "TEMPLATE_DELETE"
      handle_usertask_template_delete(usertask)
    when "PCM_PREFERENCE_UPDATE"
      handle_usertask_pcm_preference(usertask)
    else
      []
    end
  end

  def handle_usertask_template_save(usertask)
    [{:assoc => :miq_templates, :ems_ref => usertask['template_uuid']}]
  end

  def handle_usertask_template_delete(usertask)
    template = ManageIQ::Providers::InfraManager::Template.find_by(:ext_management_system => ems_event.ext_management_system, :name => usertask['labelParams'])
    if template.nil?
      []
    else
      [{:assoc => :miq_templates, :ems_ref => template.uid_ems}]
    end
  end

  def handle_usertask_pcm_preference(usertask)
    hostnames     = usertask['labelParams'].first.tr("[] ", "").split(",")
    host_ems_refs = ManageIQ::Providers::IbmPowerHmc::InfraManager::Host.where(:ext_management_system => ems_event.ext_management_system, :name => hostnames).pluck(:ems_ref)
    host_ems_refs.map { |ems_ref| {:assoc => :hosts, :ems_ref => ems_ref} }
  end
end
