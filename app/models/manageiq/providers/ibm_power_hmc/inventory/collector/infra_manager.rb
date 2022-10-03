class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def collect!
    manager.with_provider_connection do |connection|
      @connection = connection
      yield
    end
  end

  attr_reader :connection

  def ssps
    @ssps ||= begin
      connection.ssps
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("ssps query failed: #{e}")
      []
    end
  end

  def cecs
    @cecs ||= begin
      connection.managed_systems
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("managed systems query failed: #{e}")
      []
    end
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
        :client_dr  => m.client.location,
        :udid       => m.storage.udid,
        :thin       => m.storage.respond_to?(:thin) ? m.storage.thin == "true" : nil,
        :cluster_id => m.device.try(:cluster_id),
        :storage    => m.storage,
        :type       => m.storage.kind_of?(IbmPowerHmc::VirtualOpticalMedia) ? "cdrom" : "disk",
        :path       => m.device.kind_of?(IbmPowerHmc::SharedFileSystemFile) ? m.device.path : nil
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
end
