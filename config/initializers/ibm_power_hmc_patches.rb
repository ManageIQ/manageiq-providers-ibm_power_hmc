# frozen_string_literal: true

# Fixes for ibm_power_hmc template provisioning with vSCSI / vFC / VLAN overrides.
# Checked against ibm_power_hmc 0.30.0 and 0.32.1, whose setters are identical.
#
# Element sets and ordering below were measured from HMC-authored templates and from
# the draft the HMC itself produces via "Create Partition from Template".
#
# Defects in the gem:
#
#   1. schemaVersion. The setters hardcode "V1_5_0" but HMC-authored templates use
#      "V1_0". The HMC strips children of logicalPartitionConfig that carry an
#      unrecognised version before unmarshalling (SchemaVersioningUtils.stripOneNode),
#      so the PUT returns OK with the override silently removed.
#
#   2. Element position. logicalPartitionConfig is an XSD <sequence>. REXML's
#      add_element appends last, so an element the template does not already
#      contain lands after ~45 siblings and the HMC answers REST0001
#      "Invalid content was found starting with element ...".
#
#   3. Missing <Metadata><Atom/></Metadata>. Every complex element in HMC-authored
#      templates starts with it; the gem emits none.
#
#   4. Incomplete child sets. vSCSI omits name / PhyscalVolumeVTDName and vFC omits
#      locationCode.
#
#   5. Deploy timeout. HmcJob#run defaults to 120s, too short for a Deploy that
#      configures storage; on timeout its `ensure delete` removes the job so the
#      real outcome is lost.
#
require "ibm_power_hmc"

module IbmPowerHmc
  class PartitionTemplate < AbstractRest
    # Each list names the elements that FOLLOW the element in logicalPartitionConfig,
    # nearest first. Insertion happens before the first one actually present, so
    # naming an element some templates lack costs nothing.
    VFC_SUCCESSORS = %w[
      virtualSCSIClientAdapters suspendEnable SimplifiedRemoteRestartEnable
      MigrationDisable DedicatedVirtualNICs HasVirtualSerialNumber kvmCapable
    ].freeze

    VSCSI_SUCCESSORS = %w[
      suspendEnable SimplifiedRemoteRestartEnable MigrationDisable
      DedicatedVirtualNICs HasVirtualSerialNumber kvmCapable
    ].freeze

    CNA_SUCCESSORS = %w[
      SRIOVEthernetLogicalPorts SRIOVRoCELogicalPorts useCapturedSriovInfo
      useCapturedDedicateVNICInfo PowerOnWithHypervisor PendingSecureBoot
      virtualFibreChannelClientAdapters virtualSCSIClientAdapters suspendEnable
    ].freeze

    ##
    # Set the virtual SCSI client adapters.
    #
    # Child order as produced by the HMC wizard:
    #   Metadata, name, PhyscalVolumeVTDName, associatedLogicalUnits,
    #   associatedPhysicalVolume, connectingPartitionName,
    #   AssociatedTargetDevices, associatedVirtualOpticalMedia
    #
    # "PhyscalVolumeVTDName" is spelled exactly as IBM spells it in the schema
    # (missing the "i" in Physical). Do not correct it.
    #
    # A nil list is treated as empty. <name/> is emitted even when :name is not
    # given (it is then empty): that is the XML the live-HMC vSCSI deploys were
    # tested with, and no caller supplies :name today.
    #
    # @param list [Array<Hash>] per adapter:
    #   :vios     - VIOS partition name (connectingPartitionName), required
    #   :physvol  - physical volume name on that VIOS, e.g. "hdisk4", required
    #   :vtd_name - optional virtual target device name
    #   :name     - optional adapter name (the <name/> element is emitted either way)
    # @raise [ArgumentError] when :vios or :physvol is missing or blank
    def vscsi=(list = [])
      version = lpar_schema_version
      adaps = k2_new('virtualSCSIClientAdapters', version)
      (list || []).each do |vscsi|
        require_keys!(vscsi, :vios, :physvol)
        v = k2_add(adaps, 'VirtualSCSIClientAdapter', version)
        v.add_element('name').text = vscsi[:name]
        v.add_element('PhyscalVolumeVTDName').text = vscsi[:vtd_name] if vscsi[:vtd_name]
        k2_add(v, 'associatedLogicalUnits', version)
        pv = k2_add(v, 'associatedPhysicalVolume', version)
        k2_add(pv, 'PhysicalVolume', version).add_element('name').text = vscsi[:physvol] if vscsi[:physvol]
        v.add_element('connectingPartitionName').text = vscsi[:vios]
        k2_add(v, 'AssociatedTargetDevices', version)
        k2_add(v, 'associatedVirtualOpticalMedia', version)
      end
      replace_or_insert_lpar_element(adaps, VSCSI_SUCCESSORS)
    end

    ##
    # Set the virtual Fibre Channel client adapters.
    #
    # Deploy-time form produced by the HMC wizard:
    #   Metadata, locationCode, connectingPartitionName, portName
    #
    # A nil list is treated as empty.
    #
    # @param list [Array<Hash>] per adapter (all three keys are required):
    #   :vios     - VIOS partition name (connectingPartitionName)
    #   :port     - FC port on that VIOS, e.g. "fcs0"
    #   :location - that port's location code, e.g. "U78DA.ND0.WZS03EJ-P0-C1-T0"
    # @raise [ArgumentError] when a required key is missing or blank
    def vfc=(list = [])
      version = lpar_schema_version
      adaps = k2_new('virtualFibreChannelClientAdapters', version)
      (list || []).each do |vfc|
        require_keys!(vfc, :vios, :port, :location)
        v = k2_add(adaps, 'VirtualFibreChannelClientAdapter', version)
        v.add_element('locationCode').text            = vfc[:location]
        v.add_element('connectingPartitionName').text = vfc[:vios]
        v.add_element('portName').text                = vfc[:port]
      end
      replace_or_insert_lpar_element(adaps, VFC_SUCCESSORS)
    end

    ##
    # Set the client network adapters (VLANs). A nil list is treated as empty.
    # @param list [Array<Hash>] per VLAN (all three keys are required): :name, :vlan_id, :switch.
    # @raise [ArgumentError] when a required key is missing or blank
    def vlans=(list = [])
      version = lpar_schema_version
      adaps = k2_new('clientNetworkAdapters', version)
      (list || []).each do |vlan|
        require_keys!(vlan, :name, :vlan_id, :switch)
        cna  = k2_add(adaps, 'ClientNetworkAdapter', version)
        cvns = k2_add(cna, 'clientVirtualNetworks', version)
        cvn  = k2_add(cvns, 'ClientVirtualNetwork', version)
        cvn.add_element('name').text                 = vlan[:name]
        cvn.add_element('vlanId').text               = vlan[:vlan_id]
        cvn.add_element('associatedSwitchName').text = vlan[:switch]
      end
      replace_or_insert_lpar_element(adaps, CNA_SUCCESSORS)
    end

    private

    # Refuse to build an adapter with an empty element the HMC would reject (REST0001).
    def require_keys!(hash, *keys)
      missing = keys.select { |key| hash[key].to_s.strip.empty? }
      raise ArgumentError, "missing #{missing.join(', ')} in #{hash.inspect}" unless missing.empty?
    end

    # The schemaVersion this template actually uses; nil means emit no attribute.
    def lpar_schema_version
      cfg = xml.elements['logicalPartitionConfig']
      return nil if cfg.nil?

      cfg.attributes['schemaVersion'] ||
        cfg.elements.to_a.filter_map { |e| e.attributes['schemaVersion'] }.first
    end

    # Build a detached K2 element with schemaVersion and a leading <Metadata><Atom/></Metadata>.
    def k2_new(tag, version)
      el = REXML::Element.new(tag)
      el.add_attribute('schemaVersion', version) if version
      el.add_element('Metadata').add_element('Atom')
      el
    end

    # As k2_new, but attached to a parent.
    def k2_add(parent, tag, version)
      el = parent.add_element(tag)
      el.add_attribute('schemaVersion', version) if version
      el.add_element('Metadata').add_element('Atom')
      el
    end

    # Replace an element of logicalPartitionConfig in place, or insert it at a
    # schema-valid position when the template does not already contain it.
    def replace_or_insert_lpar_element(adaps, successors)
      cfg = xml.elements['logicalPartitionConfig']
      raise "template has no logicalPartitionConfig element" if cfg.nil?

      if cfg.elements[adaps.name]
        cfg.elements[adaps.name] = adaps
        return adaps
      end

      successor = successors.filter_map { |name| cfg.elements[name] }.first
      successor ? cfg.insert_before(successor, adaps) : cfg.add_element(adaps)
      adaps
    end
  end

  class Connection
    DEPLOY_TIMEOUT = 600

    ##
    # Deploy a Logical Partition from a Template (Check, Transform, Modify, Deploy).
    # Same as the gem's version, but waits up to +timeout+ seconds for the Deploy
    # instead of HmcJob#run's 120s default.
    # @return [String] The UUID of the deployed Logical Partition.
    def template_provision(template_uuid, target_sys_uuid, changes, timeout = DEPLOY_TIMEOUT)
      draft_uuid = template_check(template_uuid, target_sys_uuid).results["TEMPLATE_UUID"]
      template_transform(draft_uuid, target_sys_uuid)
      template_modify(draft_uuid, changes)
      template_deploy(draft_uuid, target_sys_uuid, false)
        .tap { |job| job.run(timeout) }
        .results["PartitionUuid"]
    end
  end
end
