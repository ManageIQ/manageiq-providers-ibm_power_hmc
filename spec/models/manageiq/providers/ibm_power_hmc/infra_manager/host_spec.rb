describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Host do
  let(:ems) do
    FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
  end

  let(:host) do
    FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "12345", :power_state => "on")
  end

  let(:samples) do
    JSON.parse(Pathname.new(__dir__).join(filename).read)["test_data"]
  end

  let(:vm) do
    FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "67890", :host => host)
  end

  context "host" do
    let(:filename) { "test_data/metrics_host.json" }
    it "process_samples" do
      allow(host).to receive(:collect_samples).and_return(samples)
      expect(host.perf_collect_metrics("realtime")).to include(
        {
          host.ems_ref => {
            Time.new(2022, 4, 7, 10, 30, 0, "+00:00")  => {
              "cpu_usage_rate_average"     => 8.475,
              "disk_usage_rate_average"    => 50.54250865885417,
              "mem_usage_absolute_average" => 30.078125,
              "net_usage_rate_average"     => 3.5191873372395834
            },
            Time.new(2022, 4, 7, 10, 30, 20, "+00:00") => {
              "cpu_usage_rate_average"     => 8.1675,
              "disk_usage_rate_average"    => 50.495846354166666,
              "mem_usage_absolute_average" => 30.078125,
              "net_usage_rate_average"     => 3.643533544921875
            },
            Time.new(2022, 4, 7, 10, 30, 40, "+00:00") => {
              "cpu_usage_rate_average"     => 7.860000000000001,
              "disk_usage_rate_average"    => 50.44918404947917,
              "mem_usage_absolute_average" => 30.078125,
              "net_usage_rate_average"     => 3.7678797526041663
            }
          }
        }
      )
    end

    it "supports metrics capture (no setting)" do
      expect(host.supports?(:capture)).to be false
    end

    it "supports metrics capture (false)" do
      FactoryBot.create(:advanced_settings, :name => "pcm_enabled", :resource => host, :value => "false")
      expect(host.supports?(:capture)).to be false
    end

    it "supports metrics capture (true)" do
      FactoryBot.create(:advanced_settings, :name => "pcm_enabled", :resource => host, :value => "true")
      expect(host.supports?(:capture)).to (be true), "unsupported reason: #{host.unsupported_reason(:capture)}"
    end

    it "supports power operations (true)" do
      FactoryBot.create(:advanced_settings, :name => "hmc_managed", :resource => host, :value => "true")
      vm.update(:raw_power_state => "not activated")
      host.power_state = "off"
      expect(host.supports?(:start)).to (be true), "unsupported reason: #{host.unsupported_reason(:start)}"
      expect(host.supports?(:stop)).to be false
      expect(host.supports?(:shutdown)).to be false
      host.power_state = "on"
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to (be true), "unsupported reason: #{host.unsupported_reason(:stop)}"
      expect(host.supports?(:shutdown)).to (be true), "unsupported reason: #{host.unsupported_reason(:shutdown)}"
      vm.update(:raw_power_state => "running")
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to (be true), "unsupported reason: #{host.unsupported_reason(:stop)}"
      expect(host.supports?(:shutdown)).to be false
    end

    it "supports power operations (false)" do
      FactoryBot.create(:advanced_settings, :name => "hmc_managed", :resource => host, :value => "false")
      vm.update(:raw_power_state => "not activated")
      host.power_state = "off"
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to be false
      expect(host.supports?(:shutdown)).to be false
      host.power_state = "on"
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to be false
      expect(host.supports?(:shutdown)).to be false
      vm.update(:raw_power_state => "running")
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to be false
      expect(host.supports?(:shutdown)).to be false
    end

    it "supports power operations (no setting)" do
      vm.update(:raw_power_state => "not activated")
      host.power_state = "off"
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to be false
      expect(host.supports?(:shutdown)).to be false
      host.power_state = "on"
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to be false
      expect(host.supports?(:shutdown)).to be false
      vm.update(:raw_power_state => "running")
      expect(host.supports?(:start)).to be false
      expect(host.supports?(:stop)).to be false
      expect(host.supports?(:shutdown)).to be false
    end
  end

  context "power_operation" do
    let(:conn) { double("IbmPowerHmc") }
    before { allow(ems).to receive(:with_provider_connection).and_yield(conn) }

    it "start" do
      expect(conn).to receive(:poweron_managed_system).with(host.ems_ref, {"operation"=>"on"})
      host.start
    end

    # "stop" test checks if the host does not stop when it is already "off"
    it "stop" do
      expect(conn).to receive(:poweroff_managed_system).with(host.ems_ref, {"immediate" => "true"})
      host.stop
    end

    # "shutdown" test checks if the host does not shutdown when it is already "off"
    it "shutdown" do
      expect(conn).to receive(:poweroff_managed_system).with(host.ems_ref)
      host.shutdown
    end
  end
end
