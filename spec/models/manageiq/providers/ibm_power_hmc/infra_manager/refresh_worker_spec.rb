describe ManageIQ::Providers::IbmPowerHmc::InfraManager::RefreshWorker do
  describe ".all_valid_ems_in_zone" do
    let(:zone) { EvmSpecHelper.local_miq_server.zone }
    let!(:parent_ems) { FactoryBot.create(:ems_ibm_power_vc, :zone => zone) }
    let!(:standalone_ems) do
      FactoryBot.create(:ems_ibm_power_hmc_infra, :zone => zone).tap do |ems|
        ems.authentications << FactoryBot.create(:authentication)
      end
    end
    let!(:child_ems) do
      FactoryBot.create(:ems_ibm_power_hmc_infra, :zone => zone, :parent_manager => parent_ems).tap do |ems|
        ems.authentications << FactoryBot.create(:authentication)
      end
    end

    it "includes standalone IBM Power HMC managers" do
      expect(described_class.all_valid_ems_in_zone).to include(standalone_ems)
    end

    it "excludes IBM Power HMC managers linked to a parent manager" do
      expect(described_class.all_valid_ems_in_zone).not_to include(child_ems)
    end
  end
end
