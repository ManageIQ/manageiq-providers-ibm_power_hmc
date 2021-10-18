class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def initialize(manager, target)
    super
  end

  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @hmc = connection.management_console

      @cecs = connection.managed_systems

      @lpars = @cecs.map do |sys|
        connection.lpars(sys.uuid)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("lpars query failed for #{sys.uuid}: #{e}")
        nil
      end.flatten.compact

      @vioses = @cecs.map do |sys|
        connection.vioses(sys.uuid)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("vioses query failed for #{sys.uuid} #{e}")
        nil
      end.flatten.compact

      @cpu_freqs = {}
      @cecs.each do |sys|
        freq = cpu_freq(connection, sys)
        @cpu_freqs[sys.uuid] = freq unless freq.nil?
      rescue => e
        $ibm_power_hmc_log.error("cpu freq query failed for #{sys.uuid}: #{e}")
      end

      $ibm_power_hmc_log.info("end collection")
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("managed systems query failed: #{e}")
    end
  end

  def cecs
    @cecs || []
  end

  def lpars
    @lpars || []
  end

  def vioses
    @vioses || []
  end

  def cpu_freqs
    @cpu_freqs || {}
  end

  def cpu_freq(connection, sys)
    # Retrieve the CPU frequency from one of the VIOSes with RMC active.
    vios = vioses.find { |v| v.sys_uuid == sys.uuid && v.rmc_state == "active" }
    return if vios.nil?

    cmd = "lsdev -dev proc0 -attr frequency"
    job = connection.cli_run(@hmc.uuid, "viosvrcmd -m \"#{sys.name}\" -p \"#{vios.name}\" -c \"#{cmd}\"")
    ret = job.results["returnCode"]&.to_i
    return if ret != 0

    result = job.results["result"]
    return if result.nil?

    result.split("\n").last.to_f / 1_000_000.0
  end
end
