class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector
  def initialize(manager, target)
    super
    @netadapters = {}
    @sriov_elps = {}
    @vnics = {}
    @ssps = {}
  end

  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @cecs = connection.managed_systems
      do_lpars(connection)
      do_vioses(connection)
      do_vswitches(connection)
      do_vlans(connection)
      do_ssps(connection)
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

  def vswitches
    @vswitches || {}
  end

  def vlans
    @vlans || {}
  end

  def vioses
    @vioses || []
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

  attr_accessor :ssps


  def ssp_lus_by_udid
    @ssp_lus_by_udid ||= ssps.flat_map(&:lus).index_by(&:udid)
  end

  def vscsi_lun_mappings
    @vscsi_lun_mappings ||= vioses.flat_map { |vios| vios.vscsi_mappings.select { |mapping| mapping.storage.kind_of?(IbmPowerHmc::LogicalUnit) } }
  end

  def vscsi_lun_mappings_by_uuid
    @vscsi_lun_mappings_by_uuid ||= vscsi_lun_mappings.group_by(&:lpar_uuid)
  end
  
  private

  def do_ssps(connection)
    @ssps = connection.ssps
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("ssps query failed : #{e}")
  end

  # Get all vlans from all managed systems(cecs)
  def do_vlans(connection)
    @vlans = {}
    @cecs.each do |sys|
      @vlans[sys.uuid] = connection.virtual_networks(sys.uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("virtual_networks query failed for #{sys.uuid}: #{e}")
    end
  end

  def do_vswitches(connection)
    @vswitches = {}
    @cecs.each do |sys|
      @vswitches[sys.uuid] = connection.virtual_switches(sys.uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("virtual_switches query failed for #{sys.uuid}: #{e}")
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
end
