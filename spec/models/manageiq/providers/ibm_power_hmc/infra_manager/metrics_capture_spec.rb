describe ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCapture do
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

  context "#perf_collect_metrics" do
    it "collects metrics for lpar" do
      cap = described_class.new(vm, ems)
      start_ts = Time.xmlschema("2022-04-04T14:00:00+02:00")
      end_ts = Time.xmlschema("2022-04-04T18:00:00+02:00")
      VCR.use_cassette("#{described_class.name.underscore}_lpar") do
        cap.perf_collect_metrics("realtime", start_ts, end_ts)
      end
    end

    it "collects metrics for host" do
      cap = described_class.new(host, ems)
      start_ts = Time.xmlschema("2022-04-04T14:00:00+02:00")
      end_ts = Time.xmlschema("2022-04-04T18:00:00+02:00")
      VCR.use_cassette("#{described_class.name.underscore}_host") do
        cap.perf_collect_metrics("realtime", start_ts, end_ts)
      end
    end

    it "collects metrics for vios" do
      cap = described_class.new(vios, ems)
      start_ts = Time.xmlschema("2022-04-04T14:00:00+02:00")
      end_ts = Time.xmlschema("2022-04-04T18:00:00+02:00")
      VCR.use_cassette("#{described_class.name.underscore}_vios") do
        cap.perf_collect_metrics("realtime", start_ts, end_ts)
      end
    end
  end
end
