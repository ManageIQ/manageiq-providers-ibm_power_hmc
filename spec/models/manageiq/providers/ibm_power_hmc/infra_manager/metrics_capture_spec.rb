describe ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCapture do
  let(:ems) do
    FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
  end

  let(:host) do
    FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "d47a585d-eaa8-3a54-b4dc-93346276ea37")
  end

  let(:lpar) do
    FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "3F3D399B-DFF3-4977-8881-C194AA47CD3A", :host => host)
  end

  let(:vios) do
    FactoryBot.create(:ibm_power_hmc_vios, :ext_management_system => ems, :ems_ref => "0D323064-36E2-455A-AB06-46BD079AD545", :host => host)
  end

  let(:start_ts) do
    Time.xmlschema("2022-04-22T16:00:00+02:00")
  end

  let(:end_ts) do
    start_ts + 2.hours
  end

  def timestamp_diffs(obj)
    obj.metrics.map.with_index { |m, i| m.timestamp - obj.metrics[i - 1].timestamp }.drop(1)
  end

  def sanity_check(obj)
    expect(obj.metrics.count).to be > 2
    expect(timestamp_diffs(obj)).to all eq(ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCaptureMixin::MIQ_SAMPLE_INTERVAL)
    expect(obj.metrics.map { |m| m.cpu_usage_rate_average }).not_to be_nil
    expect(obj.metrics.map { |m| m.disk_usage_rate_average }).not_to be_nil
    expect(obj.metrics.map { |m| m.mem_usage_absolute_average }).not_to be_nil
    expect(obj.metrics.map { |m| m.net_usage_rate_average }).not_to be_nil
  end

  context "#perf_collect_metrics" do
    it "collects metrics for lpar" do
      expect(lpar.metrics.count).to eq(0)
      VCR.use_cassette("#{described_class.name.underscore}_lpar") do
        lpar.perf_capture_realtime(start_ts, end_ts)
      end
      sanity_check(lpar)
    end

    it "collects metrics for host" do
      expect(host.metrics.count).to eq(0)
      VCR.use_cassette("#{described_class.name.underscore}_host") do
        host.perf_capture_realtime(start_ts, end_ts)
      end
      sanity_check(host)
    end

    it "collects metrics for vios" do
      expect(vios.metrics.count).to eq(0)
      VCR.use_cassette("#{described_class.name.underscore}_host") do
        vios.perf_capture_realtime(start_ts, end_ts)
      end
      sanity_check(vios)
    end
  end
end
