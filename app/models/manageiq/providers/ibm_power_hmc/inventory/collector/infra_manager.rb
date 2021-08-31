class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def initialize(manager, target)
    super
    @inventory = {}
  end

  def collect!
    $log.info("Damien: collecting")
    inventory["hosts"] = connection.managed_systems
    inventory["vms"] = []
    inventory["hosts"].each do |sys|
      inventory["vms"] += connection.lpars(sys.uuid)
      inventory["vms"] += connection.vioses(sys.uuid)
    end
    $log.info("Damien: end collection")
  end

  def inventory
    $log.info("Damien: inventory")
    @inventory ||= collect!
  end

  def ems
    $log.info("Damien: ems")
    inventory["ems"] || {}
  end

  def hosts
    $log.info("Damien: hosts")
    inventory["hosts"] || []
  end

  def vms
    $log.info("Damien: vms")
    inventory["vms"] || []
  end

  private

  def connection
    @connection ||= manager.connect
  end
end
