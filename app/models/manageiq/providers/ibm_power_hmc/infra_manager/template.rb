class ManageIQ::Providers::IbmPowerHmc::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  supports :provisioning do
    if ext_management_system
      ext_management_system.unsupported_reason(:provisioning)
    else
      _('The Template is not connected to an active Provider')
    end
  end

  supports :clone do
    _('The Template is not connected to an active Provider') if ext_management_system.nil?
  end

  def do_request(request_type, options)
    case request_type
    when 'template'
      provision_lpar(options)
    when 'clone_to_template'
      make_clone(options)
    end
  end

  def provision_lpar(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} lpar name #{options[:name]}")
    host = Host.find(options[:host_id])
    vlan = host.lans.find_by(:name => options[:vlan])

    template_overrides = {
      :lpar_name => options[:name],
      :lpar_id   => nil,
      :vlans     => [{:name => vlan.name, :vlan_id => vlan.tag, :switch => vlan.switch.name}]
    }

    template_overrides[:vscsi] = parse_storage_override(options[:vscsi_storage], :physvol) if options[:vscsi_storage].present?
    template_overrides[:vfc]   = parse_vfc_override(options[:vfc_storage], host)           if options[:vfc_storage].present?

    ext_management_system.with_provider_connection do |connection|
      connection.template_provision(ems_ref, host.ems_ref, template_overrides)
    rescue IbmPowerHmc::Connection::HttpError, IbmPowerHmc::HmcJob::JobFailed => e
      $ibm_power_hmc_log.error("error creating LPAR #{options[:name]} from template #{name}: #{e}")
      raise
    end
  end

  private

  # Parses a "vios_name:device_name" string and returns the array format
  # expected by IbmPowerHmc::PartitionTemplate#vscsi=. Surrounding whitespace is
  # ignored.
  #
  # @param value      [String]  "vios_name:device_name"
  # @param device_key [Symbol]  :physvol for vSCSI
  # @return [Array<Hash>]       e.g. [{:vios => "vios1", :physvol => "hdisk10"}]
  # @raise [MiqException::MiqProvisionError] when the VIOS name or the device name is missing
  def parse_storage_override(value, device_key)
    return [] if value.blank?

    vios_name, device_name = value.split(":", 2).map { |part| part.to_s.strip }
    raise MiqException::MiqProvisionError, "Invalid storage override '#{value}': expected VIOS_name:device_name" if vios_name.blank? || device_name.blank?

    [{:vios => vios_name, device_key => device_name}]
  end

  # Parses "vios_name:fcsN" (optionally "vios_name:fcsN:location_code") for vFC.
  # The HMC deploy form requires the physical port's location code, so when it
  # is not supplied it is resolved from the FC port inventory of that VIOS.
  # Surrounding whitespace is ignored.
  #
  # @raise [MiqException::MiqProvisionError] when the VIOS name or the port is missing
  def parse_vfc_override(value, host)
    vios_name, port, location = value.split(":", 3).map { |part| part.to_s.strip }
    raise MiqException::MiqProvisionError, "Invalid vfc_storage '#{value}': expected VIOS_name:fcsN or VIOS_name:fcsN:location_code" if vios_name.blank? || port.blank?

    location = fc_port_location(host, vios_name, port) if location.blank?
    [{:vios => vios_name, :port => port, :location => location}]
  end

  def fc_port_location(host, vios_name, port)
    vios = ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios.find_by(:host_id => host.id, :name => vios_name)
    raise MiqException::MiqProvisionError, "Cannot find VIOS #{vios_name} on host #{host.name}" if vios.nil?

    devices = vios.hardware&.guest_devices
    device  = devices&.find_by(:controller_type => "Fibre channel port", :device_name => port)
    raise MiqException::MiqProvisionError, "Cannot find location code of FC port #{port} on VIOS #{vios_name}" if device&.location.blank?

    device.location
  end

  def make_clone(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} copy name #{options[:name]}")
    ext_management_system.with_provider_connection do |connection|
      connection.template_copy(ems_ref, options[:name]).uuid
    rescue IbmPowerHmc::Connection::HttpError, IbmPowerHmc::HmcJob::JobFailed => e
      $ibm_power_hmc_log.error("error copying template #{options[:name]} to #{name}: #{e}")
      raise
    end
  end
end
