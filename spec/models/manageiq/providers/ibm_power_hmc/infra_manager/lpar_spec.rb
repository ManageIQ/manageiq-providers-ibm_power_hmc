describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar do
  let(:ems) do
    FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
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
      allow(vm).to receive(:collect_samples).and_return(samples)
      expect(vm.perf_collect_metrics("realtime")).to include(
        {
          vm.ems_ref => {
            Time.new(2022, 4, 6, 13, 30, 30, "+00:00") => {
              "cpu_usage_rate_average"     => 16.2,
              "disk_usage_rate_average"    => 33.217777766927085,
              "mem_usage_absolute_average" => 100.0,
              "net_usage_rate_average"     => 0.03468531901041667
            },
            Time.new(2022, 4, 6, 13, 30, 50, "+00:00") => {
              "cpu_usage_rate_average"     => 12.9,
              "disk_usage_rate_average"    => 28.40305555013021,
              "mem_usage_absolute_average" => 100.0,
              "net_usage_rate_average"     => 0.03623751627604167
            },
            Time.new(2022, 4, 6, 13, 31, 10, "+00:00") => {
              "cpu_usage_rate_average"     => 9.6,
              "disk_usage_rate_average"    => 23.58833333333333,
              "mem_usage_absolute_average" => 100.0,
              "net_usage_rate_average"     => 0.03778971354166667
            }
          }
        }
      )
    end
  end
end
