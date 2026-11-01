describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Template do
  let(:ems)               { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }
  let(:template)          { FactoryBot.create(:ibm_power_hmc_template, :ext_management_system => ems, :ems_ref => "template1_uuid", :name => "template1") }
  let(:archived_template) { FactoryBot.create(:ibm_power_hmc_template, :ext_management_system => nil, :ems_ref => "template2_uuid", :name => "template2") }

  context "template" do
    it "supports clone" do
      expect(template.supports?(:clone)).to (be true), "unsupported reason: #{described_class.unsupported_reason(:clone)}"
      expect(archived_template.supports?(:clone)).to be false
    end
    it "supports provisioning" do
      expect(template.supports?(:provisioning)).to (be true), "unsupported reason: #{described_class.unsupported_reason(:provisioning)}"
      expect(archived_template.supports?(:provisioning)).to be false
    end
  end

  describe "#provision_lpar" do
    let(:switch) { FactoryBot.create(:switch, :name => "ETHERNET0") }
    let(:host)   { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "sys1_uuid", :switches => [switch]) }
    let!(:lan)   { FactoryBot.create(:lan, :name => "vlan10", :tag => "10", :switch => switch) }
    let!(:vios)  { FactoryBot.create(:ibm_power_hmc_vios, :ext_management_system => ems, :host => host, :name => "vios1", :ems_ref => "vios1_uuid") }
    let!(:fcs)   do
      hw = FactoryBot.create(:hardware, :vm_or_template => vios)
      FactoryBot.create(:guest_device, :hardware => hw, :controller_type => "Fibre channel port", :device_name => "fcs0", :location => "U78DA.ND0.WZS03EJ-P0-C1-T0")
    end

    let(:base_options) do
      {:name => "new-lpar", :host_id => host.id, :vlan => "vlan10"}
    end

    it "calls template_provision without storage overrides when none are given" do
      conn = double("connection")
      expect(conn).to receive(:template_provision) do |_tmpl, _host, template_overrides|
        expect(template_overrides).not_to have_key(:vscsi)
        expect(template_overrides).not_to have_key(:vfc)
        "new-lpar-uuid"
      end
      allow(ems).to receive(:with_provider_connection).and_yield(conn)
      template.provision_lpar(base_options)
    end

    it "passes vscsi overrides when vscsi_storage is provided" do
      conn = double("connection")
      expect(conn).to receive(:template_provision) do |_tmpl, _host, template_overrides|
        expect(template_overrides[:vscsi]).to eq([{:vios => "vios1", :physvol => "hdisk10"}])
        "new-lpar-uuid"
      end
      allow(ems).to receive(:with_provider_connection).and_yield(conn)
      template.provision_lpar(base_options.merge(:vscsi_storage => "vios1:hdisk10"))
    end

    it "passes vfc overrides when vfc_storage is provided" do
      conn = double("connection")
      expect(conn).to receive(:template_provision) do |_tmpl, _host, template_overrides|
        expect(template_overrides[:vfc]).to eq([{:vios => "vios1", :port => "fcs0", :location => "U78DA.ND0.WZS03EJ-P0-C1-T0"}])
        "new-lpar-uuid"
      end
      allow(ems).to receive(:with_provider_connection).and_yield(conn)
      template.provision_lpar(base_options.merge(:vfc_storage => "vios1:fcs0"))
    end

    it "passes both vscsi and vfc overrides when both are provided" do
      conn = double("connection")
      expect(conn).to receive(:template_provision) do |_tmpl, _host, template_overrides|
        expect(template_overrides[:vscsi]).to eq([{:vios => "vios1", :physvol => "hdisk10"}])
        expect(template_overrides[:vfc]).to eq([{:vios => "vios1", :port => "fcs0", :location => "U78DA.ND0.WZS03EJ-P0-C1-T0"}])
        "new-lpar-uuid"
      end
      allow(ems).to receive(:with_provider_connection).and_yield(conn)
      template.provision_lpar(base_options.merge(:vscsi_storage => "vios1:hdisk10", :vfc_storage => "vios1:fcs0"))
    end

    it "uses the location code given in vfc_storage without a lookup" do
      conn = double("connection")
      expect(conn).to receive(:template_provision) do |_tmpl, _host, template_overrides|
        expect(template_overrides[:vfc]).to eq([{:vios => "vios1", :port => "fcs0", :location => "U78-X"}])
        "new-lpar-uuid"
      end
      allow(ems).to receive(:with_provider_connection).and_yield(conn)
      template.provision_lpar(base_options.merge(:vfc_storage => "vios1:fcs0:U78-X"))
    end

    it "ignores whitespace around the parts of the overrides" do
      conn = double("connection")
      expect(conn).to receive(:template_provision) do |_tmpl, _host, template_overrides|
        expect(template_overrides[:vscsi]).to eq([{:vios => "vios1", :physvol => "hdisk10"}])
        expect(template_overrides[:vfc]).to eq([{:vios => "vios1", :port => "fcs0", :location => "U78DA.ND0.WZS03EJ-P0-C1-T0"}])
        "new-lpar-uuid"
      end
      allow(ems).to receive(:with_provider_connection).and_yield(conn)
      template.provision_lpar(base_options.merge(:vscsi_storage => " vios1 : hdisk10 ", :vfc_storage => " vios1 : fcs0 "))
    end

    it "raises when the FC port location cannot be resolved" do
      allow(ems).to receive(:with_provider_connection).and_yield(double("connection"))
      expect { template.provision_lpar(base_options.merge(:vfc_storage => "vios1:fcs9")) }
        .to raise_error(MiqException::MiqProvisionError, /fcs9/)
    end

    it "raises a clear error when the VIOS does not exist on the host" do
      allow(ems).to receive(:with_provider_connection).and_yield(double("connection"))
      expect { template.provision_lpar(base_options.merge(:vfc_storage => "nonexistent_vios:fcs0")) }
        .to raise_error(MiqException::MiqProvisionError, /Cannot find VIOS nonexistent_vios/)
    end

    it "does not blame the VIOS when only the port is missing" do
      allow(ems).to receive(:with_provider_connection).and_yield(double("connection"))
      expect { template.provision_lpar(base_options.merge(:vfc_storage => "vios1:fcs9")) }
        .to raise_error(MiqException::MiqProvisionError, /FC port fcs9 on VIOS vios1/)
    end

    ["vios1", "vios1:", ":hdisk10", " : ", "vios1:  "].each do |value|
      it "rejects the malformed vscsi_storage #{value.inspect} before contacting the HMC" do
        expect(ems).not_to receive(:with_provider_connection)
        expect { template.provision_lpar(base_options.merge(:vscsi_storage => value)) }
          .to raise_error(MiqException::MiqProvisionError, /Invalid storage override/)
      end
    end

    ["vios1", "vios1:", ":fcs0", " : "].each do |value|
      it "rejects the malformed vfc_storage #{value.inspect} before contacting the HMC" do
        expect(ems).not_to receive(:with_provider_connection)
        expect { template.provision_lpar(base_options.merge(:vfc_storage => value)) }
          .to raise_error(MiqException::MiqProvisionError, /Invalid vfc_storage/)
      end
    end
  end
end
