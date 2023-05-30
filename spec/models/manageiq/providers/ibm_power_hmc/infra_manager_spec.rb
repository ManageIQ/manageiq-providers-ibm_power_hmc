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
end
