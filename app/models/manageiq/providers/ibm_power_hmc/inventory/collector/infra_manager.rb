class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def collect!
    manager.with_provider_connection do |connection|
      @connection = connection
      yield
    end
  end

  attr_reader :connection

  def hmc
    @hmc ||= begin
      connection.management_console
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("management console query failed: #{e}")
      nil
    end
  end

  def ssps
    @ssps ||= begin
      connection.ssps
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("ssps query failed: #{e}")
      []
    end
  end

  def cecs_quick
    @cecs_quick ||= begin
      connection.managed_systems_quick
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("managed systems quick query failed: #{e}")
      []
    end
  end

  def self.cec_unavailable?(cec_quick)
    ["failed authentication", "no connection"].include?(cec_quick["State"].downcase)
  end

  def cecs
    @cecs ||= cecs_quick.map do |cec_quick|
      connection.managed_system(cec_quick["UUID"]) unless self.class.cec_unavailable?(cec_quick)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("managed system query failed for #{cec_quick["UUID"]}: #{e}")
      nil
    end.compact
  end

  def cecs_unavailable
    @cecs_unavailable ||= cecs_quick.select { |cec_quick| self.class.cec_unavailable?(cec_quick) }
  end

  def cec_cpu_freqs_from_db
    {}
  end

  def cec_cpu_freqs_from_api
    @cec_cpu_freqs_from_api ||= cecs.map do |sys|
      [sys.uuid, cec_cpu_freq(connection, sys)]
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("cpu frequency query failed for #{sys.uuid}: #{e}")
      nil
    end.compact.to_h
  end

  def cec_cpu_freqs
    @cec_cpu_freqs ||= cec_cpu_freqs_from_api.merge(cec_cpu_freqs_from_db)
  end

  def vlans
    @vlans ||= cecs.map do |sys|
      [sys.uuid, connection.virtual_networks(sys.uuid)] unless sys.networks_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("virtual networks query failed for #{sys.uuid}: #{e}")
      nil
    end.compact.to_h
  end

  def vswitches
    @vswitches ||= cecs.map do |sys|
      [sys.uuid, connection.virtual_switches(sys.uuid)] unless sys.vswitches_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("virtual switches query failed for #{sys.uuid}: #{e}")
      nil
    end.compact.to_h
  end

  def lpars
    @lpars ||= cecs.flat_map do |sys|
      connection.lpars(sys.uuid) unless sys.lpars_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("lpars query failed for #{sys.uuid}: #{e}")
      nil
    end.compact
  end

  def vioses
    @vioses ||= cecs.flat_map do |sys|
      connection.vioses(sys.uuid) unless sys.vioses_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("vioses query failed for #{sys.uuid} #{e}")
      nil
    end.compact
  end

  def vioses_quick
    @vioses_quick ||= cecs.map do |sys|
      [sys.uuid, connection.vioses_quick(sys.uuid)] unless sys.vioses_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("vioses quick query failed for #{sys.uuid}: #{e}")
      nil
    end.compact.to_h
  end

  def pcm_enabled
    @pcm_enabled ||= begin
      connection.pcm_preferences.first.managed_system_preferences.index_by(&:id)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("pcm preferences query failed: #{e}")
      {}
    end
  end

  def vscsi_mappings
    @vscsi_mappings ||= vioses.collect(&:vscsi_mappings).flatten.select do |m|
      m.lpar_uuid && m.client && m.server && m.storage && m.device
    end
  end

  def netadapters_lpar
    @netadapters_lpar ||= lpars.map do |lpar|
      [lpar.uuid, connection.network_adapter_lpar(lpar.uuid)] unless lpar.net_adap_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("network adapters query failed for lpar #{lpar.uuid}: #{e}")
      nil
    end.compact.to_h
  end
  private :netadapters_lpar

  def netadapters_vios
    @netadapters_vios ||= vioses.map do |vios|
      [vios.uuid, connection.network_adapter_vios(vios.uuid)] unless vios.net_adap_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("network adapters query failed for vios #{vios.uuid}: #{e}")
      nil
    end.compact.to_h
  end
  private :netadapters_vios

  def netadapters
    @netadapters ||= netadapters_lpar.merge(netadapters_vios)
  end

  def sriov_elps_lpar
    @sriov_elps_lpar ||= lpars.map do |lpar|
      [lpar.uuid, connection.sriov_elp_lpar(lpar.uuid)] unless lpar.sriov_elp_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("sriov ethernet logical ports query failed for lpar #{lpar.uuid}: #{e}")
      nil
    end.compact.to_h
  end
  private :sriov_elps_lpar

  def sriov_elps_vios
    @sriov_elps_vios ||= vioses.map do |vios|
      [vios.uuid, connection.sriov_elp_vios(vios.uuid)] unless vios.sriov_elp_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("sriov ethernet logical ports query failed for vios #{vios.uuid}: #{e}")
      nil
    end.compact.to_h
  end
  private :sriov_elps_vios

  def sriov_elps
    @sriov_elps ||= sriov_elps_lpar.merge(sriov_elps_vios)
  end

  def vnics
    @vnics ||= lpars.map do |lpar|
      [lpar.uuid, connection.vnic_dedicated(lpar.uuid)] unless lpar.vnic_dedicated_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("vnics query failed for #{lpar.uuid}: #{e}")
      nil
    end.compact.to_h
  end

  def vscsi_client_adapters
    @vscsi_client_adapters ||= lpars.map do |lpar|
      [lpar.uuid, connection.vscsi_client_adapter(lpar.uuid)] unless lpar.vscsi_client_uuids.empty?
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("vscsi client adapters query failed for #{lpar.uuid}: #{e}")
      nil
    end.compact.to_h
  end

  def lpar_disks_from_db
    []
  end

  def lpar_disks_from_api
    @lpar_disks_from_api ||= vscsi_mappings.map do |m|
      {
        :lpar_uuid  => m.lpar_uuid,
        :client_drc => m.client.location,
        :udid       => m.storage.udid,
        :thin       => m.storage.respond_to?(:thin) ? m.storage.thin == "true" : nil,
        :cluster_id => m.device.try(:cluster_id),
        :storage    => m.storage,
        :type       => m.storage.kind_of?(IbmPowerHmc::VirtualOpticalMedia) ? "cdrom" : "disk",
        :mode       => m.storage.kind_of?(IbmPowerHmc::VirtualOpticalMedia) ? m.storage.mount_opts : "rw",
        :path       => m.device.kind_of?(IbmPowerHmc::SharedFileSystemFileVirtualTargetDevice) ? m.device.path : nil
      }
    end
  end

  def lpar_disks
    @lpar_disks ||= lpar_disks_from_api.concat(lpar_disks_from_db).group_by { |d| d[:lpar_uuid] }
  end

  def templates
    @templates ||= begin
      connection.templates
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("templates query failed: #{e}")
      []
    end
  end

  private

  def cec_cpu_freq(connection, sys)
    return nil if hmc.nil? || !vioses_quick.key?(sys.uuid)

    # Retrieve the CPU frequency of the CEC from one of its running VIOSes with RMC active.
    # We get the list of VIOSes using the quick API to reduce query time during targeted refresh.
    cmd = "lsdev -dev proc0 -attr frequency"
    vioses_quick[sys.uuid].select { |vios| vios["RMCState"] == "active" }.each do |vios|
      job = connection.cli_run(hmc.uuid, "viosvrcmd -m \"#{sys.name}\" --id \"#{vios["PartitionID"]}\" -c \"#{cmd}\"")
      ret = job.results["returnCode"]&.to_i
      next if ret != 0

      result = job.results["result"]
      return result.split("\n").last.to_f / 1_000_000.0 unless result.nil?
    end
    nil
  end
end
