class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def initialize(manager, target)
    super
    @inventory = {}
  end

  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    inventory["hosts"] = connection.managed_systems
    inventory["vms"] = []
    inventory["hosts"].each do |sys|
      inventory["vms"] += connection.lpars(sys.uuid)
      inventory["vms"] += connection.vioses(sys.uuid)
    end
    $ibm_power_hmc_log.info("end collection")
  end

  def inventory
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    @inventory ||= collect!
  end

  def ems
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    inventory["ems"] || {}
  end

  def hosts
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    inventory["hosts"] || []
  end

  def vms
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    inventory["vms"] || []
  end

  private

  def connection
    @connection ||= manager.connect
  end
end
