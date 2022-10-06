describe ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::TargetCollection do
  let(:ems)    { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }
  let(:host1)  { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "1", :power_state => "on") }
  let(:host2)  { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "2", :power_state => "unknown") }
  let(:host3)  { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "3", :power_state => "unknown") }
  let!(:host4) { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "1", :power_state => "on") }

  it "collect cecs" do
    cecs = {
      "1" => {"UUID"  => "1", "State" => "no connection"},
      "2" => {"UUID"  => "2", "State" => "operating"},
      "3" => {"UUID"  => "3", "State" => "failed authentication"}
    }
    collector = described_class.new(
      ems,
      InventoryRefresh::TargetCollection.new(:targets => [host1, host2, host3], :manager => ems)
    )
    collector.collect! do
      allow(collector.connection).to receive(:managed_system).with(an_instance_of(String)) do |uuid|
        expect(uuid).to be_in(cecs.keys)
        uuid
      end
      allow(collector.connection).to receive(:managed_system_quick).with(an_instance_of(String)) do |uuid|
        expect(uuid).to be_in(cecs.keys)
        cecs[uuid]
      end
      expect(collector.cecs).to contain_exactly("2")
      expect(collector.cecs_unavailable.pluck("UUID")).to contain_exactly("1", "3")
    end
  end
end
