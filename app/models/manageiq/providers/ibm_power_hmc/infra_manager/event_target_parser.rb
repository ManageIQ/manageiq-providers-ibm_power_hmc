class ManageIQ::Providers::IbmPowerHmc::InfraManager::EventTargetParser
  attr_reader :ems_event

  def initialize(ems_event)
    @ems_event = ems_event
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
      uri = URI(raw_event[:data])
      elems = uri.path.split('/')
      type, uuid = elems[-2], elems[-1]
      case type
      when "ManagedSystem"
        $ibm_power_hmc_log.info("#{self.class}##{__method__} managed system uuid #{uuid}")
        target_collection.add_target(:association => :hosts, :manager_ref => {:ems_ref => uuid})
      when "LogicalPartition", "VirtualIOServer"
        # raw_event[:detail] contains information about the properties that
        # have changed (e.g. RMCState, PartitionName, PartitionState etc...)
        # This may be used to perform quick property REST API calls to the HMC
        # instead of querying the full LPAR data.
        $ibm_power_hmc_log.info("#{self.class}##{__method__} LPAR uuid #{uuid}")
        target_collection.add_target(:association => :vms, :manager_ref => {:ems_ref => uuid})
      when "VirtualSwitch"
        $ibm_power_hmc_log.info("#{self.class}##{__method__} VirtualSwitch uuid #{uuid}")
        target_collection.add_target(:association => :hosts, :manager_ref => {:ems_ref => elems[-3]})
      when "VirtualNetwork"
        $ibm_power_hmc_log.info("#{self.class}##{__method__} VirtualNetwork uuid #{uuid}")
        target_collection.add_target(:association => :hosts, :manager_ref => {:ems_ref => elems[-3]})
      when "UserTask"
        handle_usertask(uuid, raw_event[:usertask], target_collection)
      end
    end

    # Return the set of targets from this event
    target_collection.targets
  end

  def handle_usertask(event_uuid, usertask, target_collection)
    if usertask["status"].eql?("Completed")
      case usertask["key"]
      when "TEMPLATE_PARTITION_SAVE", "TEMPLATE_PARTITION_SAVE_AS", "TEMPLATE_PARTITION_CAPTURE"
        $ibm_power_hmc_log.info("#{self.class}##{__method__} usertask uuid #{event_uuid} #{usertask['key']} uuid #{usertask['template_uuid']} name #{usertask['labelParams'].first}")
        target_collection.add_target(:association => :templates, :manager_ref => {:ems_ref => usertask['template_uuid']})
      when "TEMPLATE_DELETE"
        template = ManageIQ::Providers::InfraManager::Template.find_by(:ems_id => ems_event.ext_management_system.id, :name => usertask['labelParams'])
        $ibm_power_hmc_log.info("#{self.class}##{__method__} usertask uuid #{event_uuid} #{usertask['key']} uuid #{template.uid_ems} name #{template.name}")
        target_collection.add_target(:association => :templates, :manager_ref => {:ems_ref => template.uid_ems})
      end
    end
  end

end
