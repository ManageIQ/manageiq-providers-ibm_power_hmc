describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Refresher do
  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ibm_power_hmc)
  end

  context "#refresh" do
    let(:ems) do
      username = Rails.application.secrets.ibm_power_hmc[:username]
      password = Rails.application.secrets.ibm_power_hmc[:password]
      hostname = Rails.application.secrets.ibm_power_hmc[:hostname]

      FactoryBot.create(:ems_ibm_power_hmc_infra, :endpoints => [FactoryBot.create(:endpoint, :role => "default", :hostname => hostname, :port => 12_443)]).tap do |ems|
        ems.authentications << FactoryBot.create(:authentication, :userid => username, :password => password)
      end
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
