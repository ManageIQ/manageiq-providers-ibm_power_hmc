class ManageIQ::Providers::IbmPowerHmc::Inventory::Parser::InfraManager < ManageIQ::Providers::IbmPowerHmc::Inventory::Parser
  def parse
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    collector.collect!

    parse_cecs
    parse_lpars
    parse_vioses
  end

  def parse_cecs
    collector.cecs.each do |sys|
      host = persister.hosts.build(
        :uid_ems             => sys.uuid,
        :ems_ref             => sys.uuid,
        :name                => sys.name,
        :hypervisor_hostname => "#{sys.mtype}#{sys.model}_#{sys.serial}",
        :hostname            => sys.hostname,
        :ipaddress           => sys.ipaddr,
        :power_state         => lookup_power_state(sys.state)
      )

      parse_host_operating_system(host, sys)
      parse_host_hardware(host, sys)
    end
  end

  def parse_host_operating_system(host, sys)
    persister.host_operating_systems.build(
      :host         => host,
      :product_name => "phyp",
      :build_number => sys.fwversion
    )
  end

  def parse_host_hardware(host, sys)
    hardware = persister.host_hardwares.build(
      :host            => host,
      :cpu_type        => "ppc64",
      :bitness         => 64,
      :manufacturer    => "IBM",
      :model           => "#{sys.mtype}#{sys.model}",
      # :cpu_speed     => 2348, # in MHz
      :memory_mb       => sys.memory,
      :cpu_total_cores => sys.cpus,
      :serial_number   => sys.serial
    )

    parse_host_guest_devices(hardware, sys)
  end

  def parse_host_guest_devices(hardware, sys)
    # persister.host_guest_devices.build(
    #   :hardware    => hardware,
    #   :uid_ems     => sys.xxx,
    #   :device_name => sys.xxx,
    #   :device_type => sys.xxx
    # )
  end

  def parse_lpars
    collector.lpars.each do |lpar|
      vm = parse_lpar_common(lpar, ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar.name)
      parse_lpar_guest_devices(lpar, vm)
    end
  end

  def parse_vioses
    collector.vioses.each do |vios|
      parse_lpar_common(vios, ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios.name)
      # Add VIOS specific parsing code here.
    end
  end

  def parse_lpar_common(lpar, type)
    # Common code for LPARs and VIOSes.
    host = persister.hosts.lazy_find(lpar.sys_uuid)
    vm = persister.vms.build(
      :type            => type,
      :uid_ems         => lpar.uuid,
      :ems_ref         => lpar.uuid,
      :name            => lpar.name,
      :location        => "unknown",
      :description     => lpar.type,
      :vendor          => "ibm_power_vm",
      :raw_power_state => lpar.state,
      :host            => host
    )
    hardware = parse_vm_hardware(vm, lpar)
    parse_vm_operating_system(vm, lpar)
    parse_vm_guest_devices(lpar, hardware)
    parse_vm_advanced_settings(vm, lpar)
    vm
  end

  def parse_vm_hardware(vm, lpar)
    persister.hardwares.build(
      :vm_or_template => vm,
      :memory_mb      => lpar.memory
    )
  end

  def parse_vm_operating_system(vm, lpar)
    os_info = lpar.os.split
    persister.operating_systems.build(
      :vm_or_template => vm,
      :product_name   => os_info[0],
      :version        => os_info[1],
      :build_number   => os_info[2]
    )
  end

  def parse_vm_guest_devices(lpar, hardware)
    lpar.net_adap_uuids.map do |uuid|
      next if collector.netadapters[uuid].nil?

      mac_addr = collector.netadapters[uuid].macaddr.downcase.scan(/\w{2}/).join(':')
      persister.guest_devices.build(
        :hardware        => hardware,
        :uid_ems         => uuid,
        :device_name     => mac_addr,
        :device_type     => "ethernet",
        :controller_type => "client network adapter",
        :address         => mac_addr,
        :auto_detect     => true,
        :location        => collector.netadapters[uuid].location
      )
    end

    lpar.sriov_elp_uuids.map do |uuid|
      next if collector.sriov_elps[uuid].nil?

      mac_addr = collector.sriov_elps[uuid].macaddr.downcase.scan(/\w{2}/).join(':')
      persister.guest_devices.build(
        :hardware        => hardware,
        :uid_ems         => uuid,
        :device_name     => mac_addr,
        :device_type     => "ethernet",
        :controller_type => "sr-iov",
        :address         => mac_addr,
        :auto_detect     => true,
        :location        => collector.sriov_elps[uuid].location
      )
    end
  end

  def parse_lpar_guest_devices(lpar, vm)
    hardware = nil
    lpar.vnic_dedicated_uuids.map do |uuid|
      next if collector.vnics[uuid].nil?

      hardware ||= persister.hardwares.lazy_find(:vm_or_template => vm)
      mac_addr = collector.vnics[uuid].macaddr.downcase.scan(/\w{2}/).join(':')
      persister.guest_devices.build(
        :hardware        => hardware,
        :uid_ems         => uuid,
        :device_name     => mac_addr,
        :device_type     => "ethernet",
        :controller_type => "vnic",
        :address         => mac_addr,
        :auto_detect     => true,
        :location        => collector.vnics[uuid].location
      )
    end
  end

  def parse_vm_advanced_settings(vm, lpar)
    persister.vms_and_templates_advanced_settings.build(
      :resource     => vm,
      :name         => "partition_id",
      :display_name => _("Partition ID"),
      :description  => _("The logical partition number"),
      :value        => lpar.id.to_i,
      :read_only    => true
    )
    persister.vms_and_templates_advanced_settings.build(
      :resource     => vm,
      :name         => "reference_code",
      :display_name => _("Reference Code"),
      :description  => _("The logical partition reference code"),
      :value        => lpar.ref_code,
      :read_only    => true
    )
  end

  def lookup_power_state(state)
    # See SystemState.Enum (/rest/api/web/schema/inc/Enumerations.xsd)
    case state.downcase
    when /error.*/                    then "off"
    when "failed authentication"      then "off"
    when "incomplete"                 then "off"
    when "initializing"               then "on"
    when "no connection"              then "unknown"
    when "on demand recovery"         then "off"
    when "operating"                  then "on"
    when /pending authentication.*/   then "off"
    when "power off"                  then "off"
    when "power off in progress"      then "off"
    when "recovery"                   then "off"
    when "standby"                    then "off"
    when "version mismatch"           then "on"
    when "service processor failover" then "off"
    when "unknown"                    then "unknown"
    else                                   "off"
    end
  end
end
