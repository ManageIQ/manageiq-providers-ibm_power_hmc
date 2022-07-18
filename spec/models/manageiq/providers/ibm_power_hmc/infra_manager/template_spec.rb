describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Template do
  context "template" do
    it "supports clone" do
      expect(described_class.supports?(:clone)).to be true
    end
    it "supports provisioning" do
      expect(described_class.supports?(:clone)).to be true
    end
  end
end
