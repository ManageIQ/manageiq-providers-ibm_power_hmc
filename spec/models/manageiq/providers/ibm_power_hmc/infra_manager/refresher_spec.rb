describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Refresher do
  let(:ems) do
    FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
  end
  let(:collector) { ems.class::Inventory::Collector.new(ems) }
  let(:parser)    { ems.class::Inventory::Collector.new(collector, ems) }
  let(:persister) { ems.class::Inventory::Collector::Targeted.new(ems) }

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ibm_power_hmc)
  end

  context "#refresh" do
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

  context "#targeted_refresh" do
  end
end
