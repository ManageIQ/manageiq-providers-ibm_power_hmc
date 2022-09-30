class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @connection = connection
      yield
    end
  end

  attr_reader :connection

  def ssp_lus_by_udid
    @ssp_lus_by_udid ||= ssps.flat_map { |ssp| ssp.lus.map { |lu| [lu.udid, ssp.cluster_uuid] } }.to_h
  end

  def vscsi_lun_mappings
    @vscsi_lun_mappings ||= vioses.flat_map { |vios| vios.vscsi_mappings.select { |mapping| mapping.storage.kind_of?(IbmPowerHmc::LogicalUnit) } }
  end

  def vscsi_lun_mappings_by_uuid
    @vscsi_lun_mappings_by_uuid ||= vscsi_lun_mappings.group_by(&:lpar_uuid)
  end

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
    rescue
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
    @lpars ||=
      cecs.map do |sys|
        connection.lpars(sys.uuid) unless sys.lpars_uuids.empty?
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("lpars query failed for #{sys.uuid}: #{e}")
        nil
      end.flatten.compact
  end

  def vioses
    @vioses ||=
      cecs.map do |sys|
        connection.vioses(sys.uuid) unless sys.vioses_uuids.empty?
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("vioses query failed for #{sys.uuid} #{e}")
        nil
      end.flatten.compact
  end

  def pcm_enabled
    @pcm_enabled ||= begin
      connection.pcm_preferences.first.managed_system_preferences.index_by(&:id)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("pcm preferences query failed: #{e}")
      {}
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
    @netadapers ||= netadapters_lpar.merge(netadapters_vios)
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

  def templates
    @templates ||= begin
      connection.templates_summary.map do |template|
        connection.template(template.uuid)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("template query failed for #{template.uuid}: #{e}")
        nil
      end.compact
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("templates summary query failed: #{e}")
      []
    end
  end
end
