class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def initialize(manager, target)
    super
    @netadapters = {}
    @sriov_elps = {}
    @vnics = {}
  end

  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @hmc = connection.management_console
      do_cecs(connection)
      do_lpars(connection)
      do_vioses(connection)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("management console query failed: #{e}")
    end
    $ibm_power_hmc_log.info("end collection")
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

  def netadapters
    @netadapters || {}
  end

  def sriov_elps
    @sriov_elps || {}
  end

  def vnics
    @vnics || {}
  end

  private

  def do_cecs(connection)
    @cecs = begin
      connection.managed_systems
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("managed systems query failed: #{e}")
      []
    end

    @cpu_freqs = {}
    @cecs.each do |sys|
      freq = cpu_freq(connection, sys)
      @cpu_freqs[sys.uuid] = freq unless freq.nil?
    rescue => e
      $ibm_power_hmc_log.error("cpu freq query failed for #{sys.uuid}: #{e}")
    end
  end

  def do_lpars(connection)
    @lpars = @cecs.map do |sys|
      connection.lpars(sys.uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("lpars query failed for #{sys.uuid}: #{e}")
      nil
    end.flatten.compact

    @lpars.each do |lpar|
      do_netadapters_lpar(connection, lpar)
      do_sriov_elps_lpar(connection, lpar)
      do_vnics(connection, lpar)
    end
  end

  def do_vioses(connection)
    @vioses = @cecs.map do |sys|
      connection.vioses(sys.uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("vioses query failed for #{sys.uuid} #{e}")
      nil
    end.flatten.compact

    @vioses.each do |vios|
      do_netadapters_vios(connection, vios)
      do_sriov_elps_vios(connection, vios)
    end
  end

  def do_netadapters_lpar(connection, lpar)
    lpar.net_adap_uuids.each do |net_adap_uuid|
      @netadapters[net_adap_uuid] = connection.network_adapter_lpar(lpar.uuid, net_adap_uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("network adapter query failed for #{lpar.uuid}/#{net_adap_uuid}: #{e}")
    end
  end

  def do_netadapters_vios(connection, vios)
    vios.net_adap_uuids.each do |net_adap_uuid|
      @netadapters[net_adap_uuid] = connection.network_adapter_vios(vios.uuid, net_adap_uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("network adapter query failed for #{vios.uuid}/#{net_adap_uuid}: #{e}")
    end
  end

  def do_sriov_elps_lpar(connection, lpar)
    lpar.sriov_elp_uuids.each do |sriov_elp_uuid|
      @sriov_elps[sriov_elp_uuid] = connection.sriov_elp_lpar(lpar.uuid, sriov_elp_uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("sriov ethernet logical port query failed for #{lpar.uuid}/#{sriov_elp_uuid}: #{e}")
    end
  end

  def do_sriov_elps_vios(connection, vios)
    vios.sriov_elp_uuids.each do |sriov_elp_uuid|
      @sriov_elps[sriov_elp_uuid] = connection.sriov_elp_vios(vios.uuid, sriov_elp_uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("sriov ethernet logical port query failed for #{vios.uuid}/#{sriov_elp_uuid}: #{e}")
    end
  end

  def do_vnics(connection, lpar)
    lpar.vnic_dedicated_uuids.each do |vnic_dedicated_uuid|
      @vnics[vnic_dedicated_uuid] = connection.vnic_dedicated(lpar.uuid, vnic_dedicated_uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("vnic query failed for #{lpar.uuid}/#{vnic_dedicated_uuid}: #{e}")
    end
  end

  def cpu_freq(connection, sys)
    # Retrieve the CPU frequency from one of the VIOSes with RMC active.
    vios = vioses.find { |v| v.sys_uuid == sys.uuid && v.rmc_state == "active" }
    return if vios.nil?

    vioscmd = "lsdev -dev proc0 -attr frequency"
    cmd = %(viosvrcmd -m "#{sys.name}" -p "#{vios.name}" -c "#{vioscmd}")
    job = connection.cli_run(@hmc.uuid, cmd)
    ret = job.results["returnCode"]&.to_i
    return if ret != 0

    result = job.results["result"]
    return if result.nil?

    result.split("\n").last.to_f / 1_000_000.0
  end
end
