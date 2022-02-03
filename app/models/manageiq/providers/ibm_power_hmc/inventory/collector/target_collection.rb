class ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::TargetCollection < ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager
  def initialize(_manager, _target)
    super

    parse_targets!
  end

  def collect!
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
  end

  def cecs
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @cecs ||=
        references(:hosts).map do |ems_ref|
          connection.managed_system(ems_ref)
        rescue IbmPowerHmc::Connection::HttpError => e
          $ibm_power_hmc_log.error("error querying managed system #{ems_ref}: #{e}") unless e.status == 404
          nil
        end.compact

      @vswitches ||= {}
      @vlans ||= {}
      @cecs.each do |cec|
        @vswitches[cec.uuid] = connection.virtual_switches(cec.uuid)
        @vlans[cec.uuid] = connection.virtual_networks(cec.uuid)
      rescue IbmPowerHmc::Connection::HttpError => e
        $ibm_power_hmc_log.error("error querying virtual_switches or virtual_networks for managed system  #{cec.uuid}: #{e}") unless e.status == 404
      end
    end
  end

  def lpars
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @lpars ||=
        references(:vms).map do |ems_ref|
          connection.lpar(ems_ref)
        rescue IbmPowerHmc::Connection::HttpError => e
          $ibm_power_hmc_log.error("error querying lpar #{ems_ref}: #{e}") unless e.status == 404
          nil
        end.compact

      @lpars.each do |lpar|
        do_netadapters_lpar(connection, lpar)
        do_sriov_elps_lpar(connection, lpar)
        do_vnics(connection, lpar)
      end
    end
    @lpars || []
  end

  def vioses
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @vioses ||=
        references(:vms).map do |ems_ref|
          connection.vios(ems_ref)
        rescue IbmPowerHmc::Connection::HttpError => e
          $ibm_power_hmc_log.error("error querying vios #{ems_ref}: #{e}") unless e.status == 404
          nil
        end.compact

      @vioses.each do |vios|
        do_netadapters_vios(connection, vios)
        do_sriov_elps_vios(connection, vios)
      end
    end
    @vioses || []
  end

  def templates
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @templates ||=
        references(:miq_templates).map do |ems_ref|
          connection.template(ems_ref)
        rescue IbmPowerHmc::Connection::HttpError => e
          $ibm_power_hmc_log.error("template query failed for #{ems_ref}: #{e}") unless e.status == 404
          nil
        end.compact
    end
    @templates || []
  end

  def ssps
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    manager.with_provider_connection do |connection|
      @ssps = connection.ssps # we gather every ssp.
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error querying ssps  #{ems_ref}: #{e}") unless e.status == 404
      nil
    end
    @ssps || []
  end

  def netadapters
    @netadapters || {}
  end

  def vswitches
    @vswitches || {}
  end

  def vlans
    @vlans || {}
  end

  def sriov_elps
    @sriov_elps || {}
  end

  def vnics
    @vnics || {}
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
      else
        $ibm_power_hmc_log.info("#{self.class}##{__method__} WHAT IS THE CLASS NAME ? #{target.class.name} ")
      end
    end
  end
end
