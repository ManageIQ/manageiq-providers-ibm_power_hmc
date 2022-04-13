describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Host do
  let(:ems) do
    FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
  end

  let(:host) do
    FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "d47a585d-eaa8-3a54-b4dc-93346276ea37")
  end

  let(:samples) do
    JSON.parse(Pathname.new(__dir__).join(filename).read)["test_data"]
  end

  context "host" do
    let(:filename) { "test_data/metrics_host.json" }
    it "process_samples" do
      expect(host.process_samples(ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCapture::VIM_STYLE_COUNTERS, samples)).to include(
        {
          Time.new(2022, 4, 7, 10, 30, 0, "+00:00")  => {
            "cpu_usage_rate_average"     => 8.475,
            "disk_usage_rate_average"    => 50.54250865885417,
            "mem_usage_absolute_average" => 30.078125,
            "net_usage_rate_average"     => 3.5191873372395834
          },
          Time.new(2022, 4, 7, 10, 30, 30, "+00:00") => {
            "cpu_usage_rate_average"     => 7.860000000000001,
            "disk_usage_rate_average"    => 50.44918404947917,
            "mem_usage_absolute_average" => 30.078125,
            "net_usage_rate_average"     => 3.7678797526041663
          }
        }
      )
    end
  end
end
