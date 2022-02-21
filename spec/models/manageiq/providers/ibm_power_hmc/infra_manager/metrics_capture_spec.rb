describe ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCapture do
  let(:ems) do
    username = Rails.application.secrets.ibm_power_hmc[:username]
    password = Rails.application.secrets.ibm_power_hmc[:password]
    hostname = Rails.application.secrets.ibm_power_hmc[:hostname]

    FactoryBot.create(:ems_ibm_power_hmc_infra, :endpoints => [FactoryBot.create(:endpoint, :role => "default", :hostname => hostname, :port => 12_443)]).tap do |ems|
      ems.authentications << FactoryBot.create(:authentication, :userid => username, :password => password)
    end
  end

  let(:host) do
    FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "d47a585d-eaa8-3a54-b4dc-93346276ea37")
  end

  let(:vm) do
    FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "3F3D399B-DFF3-4977-8881-C194AA47CD3A", :host => host)
  end
  
  context "#perf_collect_metrics" do
    it "collects metrics" do
      cap = described_class.new(vm, ems)
      VCR.use_cassette(described_class.name.underscore) do
        cap.perf_collect_metrics("realtime")
      end
    end
  end
end
