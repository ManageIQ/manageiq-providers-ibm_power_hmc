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
end
