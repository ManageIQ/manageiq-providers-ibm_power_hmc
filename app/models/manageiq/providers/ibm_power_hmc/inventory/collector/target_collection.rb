class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::TargetCollection < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager
  def initialize(_manager, _target)
    super

    parse_targets!

    manager.with_provider_connection do |connection|
      @connection = connection
      infer_related_ems_refs_api!
    end

    target.manager_refs_by_association_reset
  end

  def cecs_quick
    @cecs_quick ||= references(:hosts).map do |ems_ref|
      connection.managed_system_quick(ems_ref).merge("UUID" => ems_ref)
    rescue IbmPowerHmc::Connection::HttpNotFound
      nil
    rescue => e
      $ibm_power_hmc_log.error("managed systems quick query failed for #{ems_ref}: #{e}")
      raise
    end.compact
  end

  def cec_cpu_freqs_from_db
    @cec_cpu_freqs_from_db ||= begin
      # Limit DB query to hosts that are not being refreshed but for which we have VMs that are being refreshed.
      # We don't want to use API calls for these as they are quite expensive.
      host_ems_refs = lpars.collect(&:sys_uuid).concat(vioses.collect(&:sys_uuid)).compact.uniq - references(:hosts)
      $ibm_power_hmc_log.debug("retrieving cpu_speed from db for hosts #{host_ems_refs}")
      manager.hosts.where(:ems_ref => host_ems_refs).joins(:host_hardwares).pluck("hosts.ems_ref", "hardwares.cpu_speed").to_h
    end
  end

  def lpars
    @lpars ||= references(:vms).map do |ems_ref|
      connection.lpar(ems_ref, nil, "None")
    rescue IbmPowerHmc::Connection::HttpNotFound
      nil
    rescue => e
      $ibm_power_hmc_log.error("error querying lpar #{ems_ref}: #{e}")
      raise
    end.compact
  end

  def vioses
    @vioses ||= references(:vms).map do |ems_ref|
      connection.vios(ems_ref)
    rescue IbmPowerHmc::Connection::HttpNotFound
      nil
    rescue => e
      $ibm_power_hmc_log.error("error querying vios #{ems_ref}: #{e}")
      raise
    end.compact
  end

  def templates
    @templates ||= references(:miq_templates).map do |ems_ref|
      connection.template(ems_ref)
    rescue IbmPowerHmc::Connection::HttpNotFound
      nil
    rescue => e
      $ibm_power_hmc_log.error("error querying template #{ems_ref}: #{e}")
      raise
    end.compact
  end

  def clusters
    @clusters ||= references(:storages).map do |ems_ref|
      connection.cluster(ems_ref)
    rescue IbmPowerHmc::Connection::HttpNotFound
      nil
    rescue => e
      $ibm_power_hmc_log.error("error querying cluster #{ems_ref}: #{e}")
      raise
    end.compact
  end
  private :clusters

  def ssps
    # NOTE: We're using cluster ID as ems_ref for shared storage pools.
    @ssps ||= clusters.map do |cluster|
      connection.ssp(cluster.ssp_uuid)
    rescue IbmPowerHmc::Connection::HttpNotFound
      nil
    rescue => e
      $ibm_power_hmc_log.error("error querying ssp #{cluster.ssp_uuid}: #{e}")
      raise
    end.compact
  end

  def shared_processor_pools
    @shared_processor_pools ||= references(:resource_pools).map do |ems_ref|
      sys_uuid, pool_uuid = ems_ref.split("_")
      connection.shared_processor_pool(sys_uuid, pool_uuid)
    rescue IbmPowerHmc::Connection::HttpNotFound
      nil
    rescue => e
      $ibm_power_hmc_log.error("error querying shared processor pool #{pool_uuid} on cec #{sys_uuid}: #{e}")
      raise
    end.compact
  end

  def infer_related_ems_refs_api!
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
          :mode       => disk.mode,
          :disk_type  => disk.disk_type,
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
      when ManageIQ::Providers::IbmPowerHmc::InfraManager::ResourcePool
        add_target!(:resource_pools, target.ems_ref)
      end
    end
  end
end
