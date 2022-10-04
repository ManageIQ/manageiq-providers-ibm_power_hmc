describe ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::InfraManager do
  let(:ems) { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }

  it "collects cecs" do
    collector = described_class.new(ems, nil)
    collector.collect! do
      allow(collector.connection).to receive(:managed_system).with(an_instance_of(String)) do |uuid|
        expect(uuid).to be_in(["1", "2", "3"])
        uuid
      end
      allow(collector.connection).to receive(:managed_systems_quick).and_return(
        [
          {"UUID"  => "1", "State" => "operating"},
          {"UUID"  => "2", "State" => "failed authentication"},
          {"UUID"  => "3", "State" => "no connection"}
        ]
      )
      expect(collector.cecs).to contain_exactly("1")
      expect(collector.cecs_unavailable.pluck("UUID")).to contain_exactly("2", "3")
    end
  end
end
