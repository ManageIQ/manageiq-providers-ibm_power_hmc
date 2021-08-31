class ManageIQ::Providers::IbmPowerHmc::Inventory::Parser < ManageIQ::Providers::Inventory::Parser
  require_nested :InfraManager

  def parse
    $log.info("Damien: parse")
    collector.collect!

    parse_hosts
    parse_vms
  end

  def parse_hosts
    $log.info("Damien: parse_hosts")
    collector.hosts.each do |sys|
      host = persister.hosts.find_or_build(sys.uuid)
      host.name = sys.name
      #host.vmm_vendor = "ibm_power_vc"
      host.hostname = sys.hostname
      host.ipaddress = sys.ipaddr
      host.power_state = lookup_power_state(sys.state)
    end
  end

  def parse_vms
    $log.info("Damien: parse_vms")
    collector.vms.each do |lpar|
      vm = persister.vms.find_or_build(lpar.uuid)
      vm.name = lpar.name
      vm.location = "unknown"
      vm.description = lpar.type
      vm.vendor = "ibm_power_vc" # Damien: ibm_power_hmc?
      vm.raw_power_state = lpar.state # Damien: ACTIVE, SHUTOFF, unknown, never?
      vm.host = persister.hosts.lazy_find(lpar.sys_uuid)
      #vm.connection_state = nil #lookup_connected_state(lpar.state)
      #vm.num_cpu =
      #vm.cpu_total_cores =
      #vm.ram_size =
      #vm.ipaddresses = [lpar.rmc_ipaddr] unless lpar.rmc_ipaddr.nil?
    end
  end

  def lookup_power_state(state)
    if state.downcase == "operating"
      "on"
    else
      "off"
    end
  end
end
