class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def initialize(manager, target)
    super
  end

  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @hosts = connection.managed_systems
      @vms = []
      @hosts.each do |sys|
        @vms += connection.lpars(sys.uuid)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("lpars query failed for #{sys.uuid} reason=#{e.reason} message=#{e.message}")
      end
      @hosts.each do |sys|
        @vms += connection.vioses(sys.uuid)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("vioses query failed for #{sys.uuid} reason=#{e.reason} message=#{e.message}")
      end
      $ibm_power_hmc_log.info("end collection")
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("managed systems query failed reason=#{e.reason} message=#{e.message}")
    end
  end

  def hosts
    @hosts || []
  end

  def vms
    @vms || []
  end
end
