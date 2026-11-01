require "ibm_power_hmc"

describe IbmPowerHmc::PartitionTemplate do
  # lpar_attr / child_attr control where the schemaVersion is found: on logicalPartitionConfig itself,
  # or only on one of its children.
  def build_template(with_adapters: false, with_config: true, lpar_attr: ' schemaVersion="V1_0"', child_attr: ' schemaVersion="V1_0"')
    adapters = with_adapters ? '<virtualFibreChannelClientAdapters schemaVersion="V1_0"><Metadata><Atom/></Metadata></virtualFibreChannelClientAdapters>' : ''
    config = <<~XML
      <logicalPartitionConfig#{lpar_attr}>
        <partitionName>p</partitionName>
        <clientNetworkAdapters#{child_attr}/>
        #{adapters}
        <suspendEnable>false</suspendEnable>
        <kvmCapable>false</kvmCapable>
      </logicalPartitionConfig>
    XML
    xml = <<~XML
      <entry xmlns="http://www.w3.org/2005/Atom" xmlns:etag="http://a9.com/-/spec/opensearch/1.1/">
        <id>uuid</id><published>2024-01-01T00:00:00.000Z</published>
        <content type="application/vnd.ibm.powervm.templates+xml;type=PartitionTemplate">
          <PartitionTemplate schemaVersion="V1_0">
            <partitionTemplateName>t</partitionTemplateName>
            #{config if with_config}
          </PartitionTemplate>
        </content>
      </entry>
    XML
    described_class.new(REXML::Document.new(xml).root)
  end

  def lpar_children(tmpl)
    tmpl.xml.elements['logicalPartitionConfig'].elements.map(&:name)
  end

  def vscsi_adapter(tmpl)
    tmpl.xml.elements['logicalPartitionConfig/virtualSCSIClientAdapters/VirtualSCSIClientAdapter']
  end

  it "emits vFC deploy form with locationCode, in schema order, with the template's schemaVersion" do
    tmpl = build_template
    tmpl.vfc = [{:vios => "vios2", :port => "fcs0", :location => "U78DA.ND0.WZS03EJ-P0-C1-T0"}]

    expect(lpar_children(tmpl)).to eq(%w[partitionName clientNetworkAdapters virtualFibreChannelClientAdapters suspendEnable kvmCapable])
    adaps = tmpl.xml.elements['logicalPartitionConfig/virtualFibreChannelClientAdapters']
    expect(adaps.attributes['schemaVersion']).to eq("V1_0")
    adapter = adaps.elements['VirtualFibreChannelClientAdapter']
    expect(adapter.elements.map(&:name)).to eq(%w[Metadata locationCode connectingPartitionName portName])
    expect(adapter.elements['locationCode'].text).to eq("U78DA.ND0.WZS03EJ-P0-C1-T0")
    expect(adapter.elements['portName'].text).to eq("fcs0")
  end

  it "replaces an existing vFC element in place" do
    tmpl = build_template(:with_adapters => true)
    tmpl.vfc = [{:vios => "vios2", :port => "fcs0", :location => "L"}]

    expect(lpar_children(tmpl).count("virtualFibreChannelClientAdapters")).to eq(1)
    expect(lpar_children(tmpl)).to eq(%w[partitionName clientNetworkAdapters virtualFibreChannelClientAdapters suspendEnable kvmCapable])
  end

  it "emits vSCSI with the HMC element set and IBM's PhyscalVolumeVTDName spelling" do
    tmpl = build_template
    tmpl.vscsi = [{:vios => "vios1", :physvol => "hdisk4", :vtd_name => "aa"}]

    adapter = vscsi_adapter(tmpl)
    expect(adapter.elements.map(&:name)).to eq(%w[Metadata name PhyscalVolumeVTDName associatedLogicalUnits associatedPhysicalVolume connectingPartitionName AssociatedTargetDevices associatedVirtualOpticalMedia])
    expect(adapter.elements['PhyscalVolumeVTDName'].text).to eq("aa")
    expect(adapter.elements['associatedPhysicalVolume/PhysicalVolume/name'].text).to eq("hdisk4")
    expect(adapter.elements['connectingPartitionName'].text).to eq("vios1")
    expect(lpar_children(tmpl)).to eq(%w[partitionName clientNetworkAdapters virtualSCSIClientAdapters suspendEnable kvmCapable])
  end

  it "sets the adapter name when :name is given" do
    tmpl = build_template
    tmpl.vscsi = [{:vios => "vios1", :physvol => "hdisk4", :name => "my-adapter"}]

    expect(vscsi_adapter(tmpl).elements['name'].text).to eq("my-adapter")
  end

  it "emits an empty adapter name when :name is not given" do
    tmpl = build_template
    tmpl.vscsi = [{:vios => "vios1", :physvol => "hdisk4"}]

    expect(vscsi_adapter(tmpl).elements['name'].text).to be_nil
  end

  it "omits PhyscalVolumeVTDName when no vtd_name is given" do
    tmpl = build_template
    tmpl.vscsi = [{:vios => "vios1", :physvol => "hdisk4"}]

    expect(vscsi_adapter(tmpl).elements['PhyscalVolumeVTDName']).to be_nil
  end

  it "adds Metadata/Atom to VLAN adapters and keeps their position" do
    tmpl = build_template
    tmpl.vlans = [{:name => "vlan10", :vlan_id => "10", :switch => "ETHERNET0"}]

    expect(lpar_children(tmpl)).to eq(%w[partitionName clientNetworkAdapters suspendEnable kvmCapable])
    expect(tmpl.xml.elements['logicalPartitionConfig/clientNetworkAdapters/ClientNetworkAdapter/Metadata/Atom']).not_to be_nil
  end

  describe "nil and empty adapter lists" do
    it "treats nil as an empty list" do
      tmpl = build_template
      expect { tmpl.vscsi = nil }.not_to raise_error
      expect { tmpl.vfc = nil }.not_to raise_error
      expect { tmpl.vlans = nil }.not_to raise_error
    end

    it "writes an adapters element without adapters for nil and for an empty list" do
      adapter_lists = %w[virtualSCSIClientAdapters virtualFibreChannelClientAdapters clientNetworkAdapters]
      [nil, []].each do |list|
        tmpl = build_template
        tmpl.vscsi = list
        tmpl.vfc   = list
        tmpl.vlans = list

        adapter_lists.each do |name|
          adaps = tmpl.xml.elements["logicalPartitionConfig/#{name}"]
          expect(adaps.elements.map(&:name)).to eq(%w[Metadata])
        end
      end
    end
  end

  describe "adapters with missing values" do
    it "refuses a vSCSI adapter without a VIOS or a physical volume instead of emitting an empty element" do
      tmpl = build_template
      expect { tmpl.vscsi = [{:physvol => "hdisk4"}] }.to raise_error(ArgumentError, /vios/)
      expect { tmpl.vscsi = [{:vios => "vios1"}] }.to raise_error(ArgumentError, /physvol/)
      expect { tmpl.vscsi = [{:vios => " ", :physvol => "hdisk4"}] }.to raise_error(ArgumentError, /vios/)
      expect(lpar_children(tmpl)).to eq(%w[partitionName clientNetworkAdapters suspendEnable kvmCapable])
    end

    it "refuses a vFC adapter without a location code instead of emitting an empty element" do
      tmpl = build_template
      expect { tmpl.vfc = [{:vios => "vios2", :port => "fcs0"}] }.to raise_error(ArgumentError, /location/)
    end

    it "refuses a vFC adapter without a VIOS or a port" do
      tmpl = build_template
      expect { tmpl.vfc = [{:port => "fcs0", :location => "L"}] }.to raise_error(ArgumentError, /vios/)
      expect { tmpl.vfc = [{:vios => "vios2", :port => " ", :location => "L"}] }.to raise_error(ArgumentError, /port/)
    end

    it "refuses a VLAN without a name, an id or a switch" do
      tmpl = build_template
      expect { tmpl.vlans = [{:vlan_id => "10", :switch => "ETHERNET0"}] }.to raise_error(ArgumentError, /name/)
      expect { tmpl.vlans = [{:name => "vlan10", :switch => "ETHERNET0"}] }.to raise_error(ArgumentError, /vlan_id/)
      expect { tmpl.vlans = [{:name => "vlan10", :vlan_id => "10"}] }.to raise_error(ArgumentError, /switch/)
    end

    it "leaves the template untouched when an adapter is refused" do
      tmpl = build_template
      expect { tmpl.vfc = [{:vios => "vios2", :port => "fcs0"}] }.to raise_error(ArgumentError)
      expect(lpar_children(tmpl)).to eq(%w[partitionName clientNetworkAdapters suspendEnable kvmCapable])
    end
  end

  describe "template without logicalPartitionConfig" do
    it "raises a clear error" do
      tmpl = build_template(:with_config => false)
      expect { tmpl.vscsi = [{:vios => "vios1", :physvol => "hdisk4"}] }
        .to raise_error(RuntimeError, /no logicalPartitionConfig/)
    end
  end

  describe "schemaVersion" do
    it "takes the version from logicalPartitionConfig" do
      tmpl = build_template(:lpar_attr => ' schemaVersion="V1_2"', :child_attr => '')
      tmpl.vfc = [{:vios => "vios2", :port => "fcs0", :location => "L"}]

      expect(tmpl.xml.elements['logicalPartitionConfig/virtualFibreChannelClientAdapters'].attributes['schemaVersion']).to eq("V1_2")
    end

    it "falls back to the version of a child element when logicalPartitionConfig has none" do
      tmpl = build_template(:lpar_attr => '', :child_attr => ' schemaVersion="V1_3"')
      tmpl.vfc = [{:vios => "vios2", :port => "fcs0", :location => "L"}]

      expect(tmpl.xml.elements['logicalPartitionConfig/virtualFibreChannelClientAdapters'].attributes['schemaVersion']).to eq("V1_3")
    end

    it "emits no schemaVersion attribute when the template has none anywhere" do
      tmpl = build_template(:lpar_attr => '', :child_attr => '')
      tmpl.vfc = [{:vios => "vios2", :port => "fcs0", :location => "L"}]

      adaps = tmpl.xml.elements['logicalPartitionConfig/virtualFibreChannelClientAdapters']
      expect(adaps.attributes['schemaVersion']).to be_nil
    end
  end
end
