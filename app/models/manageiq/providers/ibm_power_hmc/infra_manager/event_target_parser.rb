class ManageIQ::Providers::IbmPowerHmc::InfraManager::EventTargetParser
  attr_reader :ems_event

  def initialize(ems_event)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} #{ems_event}")
    @ems_event = ems_event
  end

  def parse
    $ibm_power_hmc_log.info("#{self.class}##{__method__} #{ems_event}")

    target_collection = InventoryRefresh::TargetCollection.new(
      :manager => ems_event.ext_management_system,
      :event   => ems_event
    )

    raw_event = ems_event.full_data

    case raw_event.type
    when /.*_URI/
      uri = URI(raw_event.data)
      elems = uri.path.split('/')
      uuid = elems[-1]
      type = elems[-2]
      case type
      when "ManagedSystem"
        $ibm_power_hmc_log.info("#{self.class}##{__method__} managed system uuid #{uuid}")
        target_collection.add_target(:association => :hosts, :manager_ref => {:ems_ref => uuid})
      when "LogicalPartition"
        $ibm_power_hmc_log.info("#{self.class}##{__method__} LPAR uuid #{uuid}")
        target_collection.add_target(:association => :vms, :manager_ref => {:ems_ref => uuid})
      end
    end

    # Return the set of targets from this event
    target_collection.targets
  end
end
