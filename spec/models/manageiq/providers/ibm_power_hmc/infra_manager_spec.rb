describe ManageIQ::Providers::IbmPowerHmc::InfraManager do
  it "returns the expected value for the ems_type method" do
    expect(described_class.ems_type).to eq('ibm_power_hmc')
  end

  it "returns the expected value for the description method" do
    expect(described_class.description).to eq('IBM Power HMC')
  end

  it "returns the expected value for the hostname_required? method" do
    expect(described_class.hostname_required?).to eq(true)
  end

  describe "#catalog_types" do
    let(:ems) { FactoryBot.create(:ems_ibm_power_hmc_infra) }

    it "catalog_types" do
      expect(ems.catalog_types["ibm_power_hmc"]).to eq "IBM Power HMC"
    end
  end

  describe ".parent_ems_id_options" do
    it "returns an empty array when no PowerVC managers exist" do
      expect(described_class.send(:parent_ems_id_options)).to eq([])
    end

    context "with PowerVC managers" do
      let!(:power_vc_1) { FactoryBot.create(:ems_ibm_power_vc, :name => "PowerVC 1") }
      let!(:power_vc_2) { FactoryBot.create(:ems_ibm_power_vc, :name => "PowerVC 2") }
      let!(:power_vc_3) { FactoryBot.create(:ems_ibm_power_vc, :name => "powerVC 3") }

      it "returns formatted options with label and value" do
        options = described_class.send(:parent_ems_id_options)
        expect(options).to match_array(
          [
            {:label => power_vc_1.name, :value => power_vc_1.id.to_s},
            {:label => power_vc_2.name, :value => power_vc_2.id.to_s},
            {:label => power_vc_3.name, :value => power_vc_3.id.to_s}
          ]
        )
      end

      it "converts id to string in value field" do
        options = described_class.send(:parent_ems_id_options)
        option = options.find { |opt| opt[:label] == "PowerVC 1" }
        expect(option[:value]).to eq(power_vc_1.id.to_s)
      end

      it "includes all PowerVC managers" do
        options = described_class.send(:parent_ems_id_options)
        values = options.map { |opt| opt[:value] }
        expect(values).to contain_exactly(
          power_vc_1.id.to_s,
          power_vc_2.id.to_s,
          power_vc_3.id.to_s
        )
      end
    end
  end

  describe ".create_from_params" do
    let(:zone) { EvmSpecHelper.create_guid_miq_server_zone.last }
    let(:params) { {"name" => "HMC Manager", "zone" => zone} }
    let(:endpoints) { [{"role" => "default", "hostname" => "hmc.example.com", "port" => 443, "security_protocol" => "ssl-with-validation"}] }
    let(:authentications) { [{"authtype" => "default", "userid" => "hscroot", "password" => "secret"}] }

    context "with a parent_ems_id for an IbmPowerVc parent" do
      let!(:power_vc) { FactoryBot.create(:ems_ibm_power_vc, :name => "PowerVC Manager") }
      let(:params_with_parent) { params.merge("parent_ems_id" => power_vc.id) }

      it "creates the EMS with the parent relationship" do
        ems = described_class.create_from_params(params_with_parent, endpoints, authentications)
        expect(ems.name).to eq(params["name"])
        expect(ems.parent_manager).to eq(power_vc)
        expect(ems.parent_ems_id).to eq(power_vc.id)
      end

      it "creates the endpoints correctly" do
        ems = described_class.create_from_params(params_with_parent, endpoints, authentications)
        expect(ems.endpoints.count).to eq(1)
        expect(ems.endpoints.find_by(:role => "default")).to have_attributes(
          :hostname          => "hmc.example.com",
          :port              => 443,
          :security_protocol => "ssl-with-validation"
        )
      end

      it "creates the authentications correctly" do
        ems = described_class.create_from_params(params_with_parent, endpoints, authentications)
        expect(ems.authentications.count).to eq(1)
        expect(ems.authentications.find_by(:authtype => "default")).to have_attributes(
          :userid => "hscroot"
        )
      end
    end

    context "without a parent_ems_id" do
      it "creates the EMS without a parent relationship" do
        ems = described_class.create_from_params(params, endpoints, authentications)
        expect(ems.name).to eq(params["name"])
        expect(ems.parent_manager).to be_nil
        expect(ems.parent_ems_id).to be_nil
      end
    end
  end

  describe "#edit_with_params" do
    let(:zone) { EvmSpecHelper.create_guid_miq_server_zone.last }
    let!(:ems) do
      FactoryBot.create(:ems_ibm_power_hmc_infra, :name => "HMC Manager", :zone => zone).tap do |ems|
        ems.authentications << FactoryBot.create(:authentication, :authtype => "default", :userid => "hscroot", :password => "secret")
      end
    end
    let(:params) { {"name" => ems.name, "zone" => ems.zone} }
    let(:endpoints) { [{"role" => "default", "hostname" => ems.hostname, "port" => ems.port}] }
    let(:authentications) { [{"authtype" => "default", "userid" => "hscroot"}] }

    context "setting a parent_ems_id" do
      let!(:power_vc) { FactoryBot.create(:ems_ibm_power_vc, :name => "PowerVC Manager") }
      let(:params_with_parent) { params.merge("parent_ems_id" => power_vc.id) }

      it "sets the parent relationship" do
        expect(ems.parent_manager).to be_nil

        ems.edit_with_params(params_with_parent, endpoints, authentications)
        ems.reload

        expect(ems.parent_manager).to eq(power_vc)
        expect(ems.parent_ems_id).to eq(power_vc.id)
      end
    end

    context "clearing a parent_ems_id" do
      let!(:power_vc) { FactoryBot.create(:ems_ibm_power_vc, :name => "PowerVC Manager") }

      before do
        ems.update!(:parent_ems_id => power_vc.id)
      end

      it "clears the parent relationship when parent_ems_id is nil" do
        expect(ems.parent_manager).to eq(power_vc)

        params_without_parent = params.merge("parent_ems_id" => nil)
        ems.edit_with_params(params_without_parent, endpoints, authentications)
        ems.reload

        expect(ems.parent_manager).to be_nil
        expect(ems.parent_ems_id).to be_nil
      end

      it "clears the parent relationship when parent_ems_id is empty string" do
        expect(ems.parent_manager).to eq(power_vc)

        params_without_parent = params.merge("parent_ems_id" => "")
        ems.edit_with_params(params_without_parent, endpoints, authentications)
        ems.reload

        expect(ems.parent_manager).to be_nil
        expect(ems.parent_ems_id).to be_nil
      end
    end

    context "changing parent_ems_id" do
      let!(:power_vc_1) { FactoryBot.create(:ems_ibm_power_vc, :name => "PowerVC 1") }
      let!(:power_vc_2) { FactoryBot.create(:ems_ibm_power_vc, :name => "PowerVC 2") }

      before do
        ems.update!(:parent_ems_id => power_vc_1.id)
      end

      it "changes from one parent to another" do
        expect(ems.parent_manager).to eq(power_vc_1)

        params_with_new_parent = params.merge("parent_ems_id" => power_vc_2.id)
        ems.edit_with_params(params_with_new_parent, endpoints, authentications)
        ems.reload

        expect(ems.parent_manager).to eq(power_vc_2)
        expect(ems.parent_ems_id).to eq(power_vc_2.id)
      end
    end
  end

end
