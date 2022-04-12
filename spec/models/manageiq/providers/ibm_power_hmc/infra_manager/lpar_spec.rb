describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar do
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

  let(:vios) do
    FactoryBot.create(:ibm_power_hmc_vios, :ext_management_system => ems, :ems_ref => "0D323064-36E2-455A-AB06-46BD079AD545", :host => host)
  end

  let(:samples) do
    JSON.parse(Pathname.new(__dir__).join(filename).read)["test_data"]
  end

  context "lpar" do
    let(:filename) { "test_data/metrics_lpar.json" }
    it "process_samples" do
      expect(vm.process_samples(ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCapture::VIM_STYLE_COUNTERS, samples)).to include(
        {
          Time.new(2022, 4, 6, 13, 30, 30, "+00:00") => {
            "cpu_usage_rate_average"     => 16.2,
            "disk_usage_rate_average"    => 33.217777766927085,
            "mem_usage_absolute_average" => 100.0,
            "net_usage_rate_average"     => 0.03468531901041667
          },
          Time.new(2022, 4, 6, 13, 31, 0, "+00:00")  => {
            "cpu_usage_rate_average"     => 9.6,
            "disk_usage_rate_average"    => 23.58833333333333,
            "mem_usage_absolute_average" => 100.0,
            "net_usage_rate_average"     => 0.03778971354166667
          }
        }
      )
    end
  end
end
