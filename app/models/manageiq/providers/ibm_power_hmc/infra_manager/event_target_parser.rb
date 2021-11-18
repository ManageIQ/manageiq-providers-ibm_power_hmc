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
        $ibm_power_hmc_log.error("#{self.class}##{__method__} usertask uuid #{uuid} #{raw_event[:usertask]["key"]}")
        #target_collection.process_usertask(raw_event[:test])
      end
    end

    # Return the set of targets from this event
    target_collection.targets
  end
end
