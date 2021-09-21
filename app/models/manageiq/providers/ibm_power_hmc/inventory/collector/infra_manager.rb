class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def initialize(manager, target)
    super
  end

  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    @hosts = connection.managed_systems
    @vms = []
    @hosts.each do |sys|
      @vms += connection.lpars(sys.uuid)
      @vms += connection.vioses(sys.uuid)
    end
    connection.logoff
    $ibm_power_hmc_log.info("end collection")
  end

  def hosts
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    @hosts || []
  end

  def vms
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    @vms || []
  end

  private

  def connection
    @connection ||= manager.connect
  end
end
