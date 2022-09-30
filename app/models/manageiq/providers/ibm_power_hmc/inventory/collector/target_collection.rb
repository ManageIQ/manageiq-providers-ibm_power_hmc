class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::TargetCollection < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager
  def initialize(_manager, _target)
    super

    parse_targets!
  end

  def cecs
    @cecs ||=
      references(:hosts).map do |ems_ref|
        connection.managed_system(ems_ref)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("error querying managed system #{ems_ref}: #{e}") unless e.status == 404
        nil
      end.compact
  end

  def lpars
    @lpars ||=
      references(:vms).map do |ems_ref|
        connection.lpar(ems_ref)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("error querying lpar #{ems_ref}: #{e}") unless e.status == 404
        nil
      end.compact
  end

  def vioses
    @vioses ||=
      references(:vms).map do |ems_ref|
        connection.vios(ems_ref)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("error querying vios #{ems_ref}: #{e}") unless e.status == 404
        nil
      end.compact
  end

  def templates
    @templates ||=
      references(:miq_templates).map do |ems_ref|
        connection.template(ems_ref)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("template query failed for #{ems_ref}: #{e}") unless e.status == 404
        nil
      end.compact
  end

  def ssps
    @ssps ||= begin
      references(:storage).empty? ? [] : connection.ssps
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying ssps: #{e}") unless e.status == 404
      []
    end.compact
  end

  private

  def parse_targets!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")

    target.targets.each do |target|
      case target
      when Host
        add_target!(:hosts, target.ems_ref)
      when ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar, ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios
        add_target!(:vms, target.ems_ref)
      when HostSwitch
        add_target!(:host_virtual_switches, target.ems_ref)
      when Lan
        add_target!(:lans, target.ems_ref)
      when ManageIQ::Providers::IbmPowerHmc::InfraManager::Template
        add_target!(:miq_templates, target.ems_ref)
      when ManageIQ::Providers::IbmPowerHmc::InfraManager::Storage
        add_target!(:storages, target.ems_ref)
      end
    end
  end
end
