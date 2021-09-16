class ManageIQ::Providers::IbmPowerHmc::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :InfraManager

  def parse
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    collector.collect!

    parse_hosts
    parse_vms
  end

  def parse_hosts
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    collector.hosts.each do |sys|
      host = persister.hosts.find_or_build(sys.uuid)
      host.name = sys.name
      # host.vmm_vendor = "ibm_power_hmc"
      host.hypervisor_hostname = "#{sys.mtype}#{sys.model}_#{sys.serial}"
      host.hostname = sys.hostname
      host.ipaddress = sys.ipaddr
      host.power_state = lookup_power_state(sys.state)

      parse_host_operating_system(host, sys)
      parse_host_hardware(host, sys)
    end
  end

  def parse_host_operating_system(host, sys)
    # Damien: PHYP version?
    # persister.host_operating_systems.build(
    #   :host         => host,
    # )
  end

  def parse_host_hardware(host, sys)
    hardware = persister.host_hardwares.build(
      :host                 => host,
      # :cpu_type             => sys.xxx,
      :manufacturer         => "IBM",
      :model                => "POWER",
      # :cpu_speed            => 2348, # in MHz
      :memory_mb            => sys.memory, # in MB
      # :cpu_sockets          => 1,
      :cpu_total_cores      => sys.cpus,
      # :cpu_cores_per_socket => sys.cpus,
      :serial_number        => "123456",
    )

    parse_host_guest_devices(hardware, sys)
  end

  def parse_host_guest_devices(hardware, sys)
    # persister.host_guest_devices.build(
    #   :hardware        => hardware,
    #   :uid_ems         => sys.xxx,
    #   :device_name     => sys.xxx,
    #   :device_type     => sys.xxx,
    # )
  end

  def parse_vms
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    collector.vms.each do |lpar|
      vm = persister.vms.find_or_build(lpar.uuid)
      vm.name = lpar.name
      vm.location = "unknown"
      vm.description = lpar.type
      vm.vendor = "ibm_power_vc" # Damien: add ibm_power_hmc to MIQ
      vm.raw_power_state = lpar.state
      vm.host = persister.hosts.lazy_find(lpar.sys_uuid)
      # vm.connection_state = nil # Damien: rmc_state?
      # vm.ipaddresses = [lpar.rmc_ipaddr] unless lpar.rmc_ipaddr.nil?

      parse_vm_hardware(vm, lpar)
    end
  end

  def parse_vm_hardware(vm, lpar)
    persister.hardwares.build(
      :vm_or_template     => vm,
      # :cpu_total_cores    => lpar.xxx,
      # :guest_os           => lpar.xxx,
      # :guest_os_full_name => lpar.xxx,
      :memory_mb          => lpar.memory,
      # :cpu_type           => lpar.xxx,
    )
  end

  def lookup_power_state(state)
    if state.downcase == "operating"
      "on"
    else
      "off"
    end
  end
end
