describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios do
  let(:ems) do
    FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
  end

  let(:host) do
    FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "d47a585d-eaa8-3a54-b4dc-93346276ea37")
  end

  let(:vios) do
    FactoryBot.create(:ibm_power_hmc_vios, :ext_management_system => ems, :ems_ref => "0D323064-36E2-455A-AB06-46BD079AD545", :host => host)
  end

  let(:samples) do
    JSON.parse(Pathname.new(__dir__).join(filename).read)["test_data"]
  end

  context "vios" do
    it "supports clone" do
      expect(described_class.supports?(:clone)).to be false
    end
    it "supports publish" do
      expect(described_class.supports?(:publish)).to be false
    end
    it "supports migrate" do
      expect(described_class.supports?(:migrate)).to be false
    end
  end

  context "performance" do
    let(:filename) { "test_data/metrics_host.json" }
    it "process_samples" do
      allow(vios).to receive(:collect_samples).and_return(samples)
      expect(vios.perf_collect_metrics("realtime")).to include(
        {
          vios.ems_ref => {
            Time.new(2022, 4, 7, 10, 30, 0, "+00:00")  => {
              "cpu_usage_rate_average"     => 1.2,
              "disk_usage_rate_average"    => 6.7747222005208325,
              "mem_usage_absolute_average" => 72.05078125,
              "net_usage_rate_average"     => 2.985620703125
            },
            Time.new(2022, 4, 7, 10, 30, 20, "+00:00") => {
              "cpu_usage_rate_average"     => 1.0,
              "disk_usage_rate_average"    => 9.811258675130208,
              "mem_usage_absolute_average" => 72.05078125,
              "net_usage_rate_average"     => 3.1246045247395835
            },
            Time.new(2022, 4, 7, 10, 30, 40, "+00:00") => {
              "cpu_usage_rate_average"     => 0.8,
              "disk_usage_rate_average"    => 12.847795149739586,
              "mem_usage_absolute_average" => 72.05078125,
              "net_usage_rate_average"     => 3.2635883463541666
            }
          }
        }
      )
    end
  end
end
