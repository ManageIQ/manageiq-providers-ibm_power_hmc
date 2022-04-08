describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios do
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

  let(:vios) do
    FactoryBot.create(:ibm_power_hmc_vios, :ext_management_system => ems, :ems_ref => "0D323064-36E2-455A-AB06-46BD079AD545", :host => host)
  end

  let(:samples) do
    JSON.parse(File.read(File.join(File.dirname(__FILE__), filename)))["test_data"]
  end

  context "vios" do
    let(:filename) { "test_data/metrics_host.json" }
    it "process_samples" do
      expect(vios.process_samples(ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCapture::VIM_STYLE_COUNTERS, samples)).to include(
        {
          Time.new(2022, 4, 7, 10, 30, 0, "+00:00") => {
            "cpu_usage_rate_average"     => 1.2,
            "disk_usage_rate_average"    => 6.774722200520833,
            "mem_usage_absolute_average" => 72.05078125,
            "net_usage_rate_average"     => 2.985620703125
          },
          Time.new(2022, 4, 7, 10, 30, 30, "+00:00")  => {
            "cpu_usage_rate_average"     => 0.8,
            "disk_usage_rate_average"    => 12.847795149739584,
            "mem_usage_absolute_average" => 72.05078125,
            "net_usage_rate_average"     => 3.2635883463541666
          }
        }
      )
    end
  end
end
