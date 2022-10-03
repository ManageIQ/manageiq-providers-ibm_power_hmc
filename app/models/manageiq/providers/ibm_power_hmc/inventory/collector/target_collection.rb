class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::TargetCollection < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager
  def initialize(_manager, _target)
    super

    parse_targets!
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
