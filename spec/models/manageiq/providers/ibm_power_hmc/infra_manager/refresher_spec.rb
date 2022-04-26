describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Refresher do
  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ibm_power_hmc)
  end

  context "#refresh" do
    let(:ems) do
      FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
    end

    it "full refresh" do
      2.times do
        full_refresh(ems)
        ems.reload
      end
    end

    def full_refresh(ems)
      VCR.use_cassette(described_class.name.underscore) do
        EmsRefresh.refresh(ems)
      end
    end
  end
end
