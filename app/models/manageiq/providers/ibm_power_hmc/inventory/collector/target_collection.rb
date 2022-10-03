class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::TargetCollection < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager
  def initialize(_manager, _target)
    super

    parse_targets!

    manager.with_provider_connection do |connection|
      @connection = connection
      infer_ems_refs_from_api
    end

    target.manager_refs_by_association_reset
  end

  def cecs
    @cecs ||= references(:hosts).map do |ems_ref|
      connection.managed_system(ems_ref)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying managed system #{ems_ref}: #{e}") unless e.status == 404
      nil
    end.compact
  end

  def lpars
    @lpars ||= references(:vms).map do |ems_ref|
      connection.lpar(ems_ref)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying lpar #{ems_ref}: #{e}") unless e.status == 404
      nil
    end.compact
  end

  def vioses
    @vioses ||= references(:vms).map do |ems_ref|
      connection.vios(ems_ref)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying vios #{ems_ref}: #{e}") unless e.status == 404
      nil
    end.compact
  end

  def templates
    @templates ||= references(:miq_templates).map do |ems_ref|
      connection.template(ems_ref)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying template #{ems_ref}: #{e}") unless e.status == 404
      nil
    end.compact
  end

  def clusters
    @clusters ||= references(:storages).map do |ems_ref|
      connection.clusters(ems_ref)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying cluster #{ems_ref}: #{e}") unless e.status == 404
      nil
    end.compact
  end
  private :clusters

  def ssps
    @ssps ||= clusters.map do |cluster|
      connection.ssp(cluster.ssp_uuid)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying ssp: #{e}") unless e.status == 404
      []
    end.compact
  end

  def infer_ems_refs_from_api
    # Refresh LPARs that have disk paths going through any of the updated VIOSes.
    vscsi_mappings.each do |m|
      $ibm_power_hmc_log.debug("#{self.class}##{__method__} add LPAR target #{m.lpar_uuid}")
      add_target!(:vms, m.lpar_uuid)
    end
  end

  def lpar_disks_from_db
    # Limit DB query to LPARs only (not VIOSes) and only for the ones that still have VSCSI client adapters.
    @lpar_disks_from_db ||= manager.vms.where(:ems_ref => vscsi_client_adapters.keys).joins(:disks).select("vms.ems_ref as lpar_uuid", "disks.*").flat_map do |disk|
      disk.location.split(",").map do |path|
        # Preserve only paths to VIOSes that are not part of the target refresh.
        next if vscsi_client_adapters[disk.lpar_uuid].any? { |c| c.location == path && references(:vms).include?(c.vios_uuid) }

        {
          :lpar_uuid  => disk.lpar_uuid,
          :client_drc => path,
          :udid       => disk.device_name,
          :size       => disk.size,
          :thin       => disk.thin,
          :type       => disk.device_type,
          :path       => disk.filename
        }
      end.compact
    end
  end

  private

  def parse_targets!
    target.targets.each do |target|
      case target
      when Host
        add_target!(:hosts, target.ems_ref)
      when ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar, ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios
        add_target!(:vms, target.ems_ref)
      when ManageIQ::Providers::IbmPowerHmc::InfraManager::Template
        add_target!(:miq_templates, target.ems_ref)
      when ManageIQ::Providers::IbmPowerHmc::InfraManager::Storage
        add_target!(:storages, target.ems_ref)
      end
    end
  end
end
