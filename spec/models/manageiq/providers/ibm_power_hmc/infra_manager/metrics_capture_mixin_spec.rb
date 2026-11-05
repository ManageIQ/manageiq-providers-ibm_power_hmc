describe ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCaptureMixin do
  before(:each) do
    @test_obj = Object.new
    @test_obj.extend(described_class)
  end

  let(:ts) do
    Time.new(2022, 4, 21, 14, 49, 0, "+02:00")
  end

  let(:processed_samples) do
    {
      ts                                        => {
        :cat1 => 0,
        :cat2 => 100,
        :cat4 => 100
      },
      ts + described_class::SAMPLE_DURATION     => {
        :cat1 => 50,
        :cat2 => 0,
        :cat3 => 100,
        :cat4 => 100
      },
      ts + described_class::SAMPLE_DURATION * 2 => {
        :cat1 => 100,
        :cat2 => 100,
        :cat3 => 100
      },
      ts + described_class::SAMPLE_DURATION * 3 => {
        :cat1 => 0,
        :cat2 => 0,
        :cat3 => 0,
        :cat4 => 0
      }
    }
  end

  # HMC sample timestamps are the END of the 30s window they cover:
  #   ts      covers [ts - 30s, ts)
  #   ts + 30 covers [ts,       ts + 30s)
  #   ts + 60 covers [ts + 30s, ts + 60s)
  #   ts + 90 covers [ts + 60s, ts + 90s)
  # Interpolated samples start on the 20s grid, here ts - 20s since ts is on the grid.
  let(:interpolated_samples) do
    {
      ts - described_class::MIQ_SAMPLE_INTERVAL     => {
        :cat1 => 0,
        :cat2 => 100,
        :cat4 => 100
      },
      ts                                            => {
        :cat1 => 50,
        :cat2 => 0,
        :cat3 => 100,
        :cat4 => 100
      },
      ts + described_class::MIQ_SAMPLE_INTERVAL     => {
        :cat1 => 75,
        :cat2 => 50,
        :cat3 => 100
      },
      ts + described_class::MIQ_SAMPLE_INTERVAL * 2 => {
        :cat1 => 100,
        :cat2 => 100,
        :cat3 => 100
      },
      ts + described_class::MIQ_SAMPLE_INTERVAL * 3 => {
        :cat1 => 0,
        :cat2 => 0,
        :cat3 => 0,
        :cat4 => 0
      }
    }
  end

  it "constants" do
    # Expected results in this file are based on these values
    expect(described_class::SAMPLE_DURATION).to eq 30.seconds
    expect(described_class::MIQ_SAMPLE_INTERVAL).to eq 20.seconds
  end

  it "cpu_usage_rate_average" do
    expect(@test_obj.cpu_usage_rate_average({"utilizedProcUnits" => [5], "entitledProcUnits" => [10]})).to eq 50.0
    expect(@test_obj.cpu_usage_rate_average({"utilizedProcUnits" => [1, 1], "entitledProcUnits" => [10, 10]})).to eq 10.0
    expect(@test_obj.cpu_usage_rate_average({"utilizedProcUnits" => [0], "entitledProcUnits" => [0]})).to be_nil
  end

  it "cpu_usage_rate_average_host" do
    expect(@test_obj.cpu_usage_rate_average_host({"utilizedProcUnits" => [5], "configurableProcUnits" => [10]})).to eq 50.0
    expect(@test_obj.cpu_usage_rate_average_host({"utilizedProcUnits" => [1, 1], "configurableProcUnits" => [10, 10]})).to eq 10.0
    expect(@test_obj.cpu_usage_rate_average_host({"utilizedProcUnits" => [0], "configurableProcUnits" => [0]})).to be_nil
  end

  let(:disk_data_lpar) do
    {
      "adap_type1" => [
        {
          "readBytes"  => [1024, 2048],
          "writeBytes" => [3072, 4096]
        },
        {
          "readBytes"  => [1024, 2048],
          "writeBytes" => [3072, 4096]
        }
      ],
      "adap_type2" => [
        {
          "readBytes"  => [0],
          "writeBytes" => [20_480]
        },
        {
          "readBytes"  => [0],
          "writeBytes" => [20_480]
        }
      ]
    }
  end

  it "disk_usage_rate_average" do
    expect(@test_obj.disk_usage_rate_average(disk_data_lpar)).to eq 2.0
  end

  let(:disk_data_vios) do
    {
      "adap_type1" => [
        {"transmittedBytes" => [1024, 1024]},
        {"transmittedBytes" => [1024, 2048]}
      ],
      "adap_type2" => [
        {"transmittedBytes" => [20_480]},
        {"transmittedBytes" => [20_480]}
      ]
    }
  end

  let(:disk_data_host) do
    {
      "viosUtil" => [
        {"storage" => disk_data_vios},
        {"storage" => disk_data_vios}
      ]
    }
  end

  it "disk_usage_rate_average_vios" do
    expect(@test_obj.disk_usage_rate_average_vios(disk_data_vios)).to eq 1.5
  end

  it "disk_usage_rate_average_all_vios" do
    expect(@test_obj.disk_usage_rate_average_all_vios(disk_data_host)).to eq 3.0
  end

  it "mem_usage_absolute_average" do
    expect(@test_obj.mem_usage_absolute_average({"backedPhysicalMem" => [5], "logicalMem" => [10]})).to eq 50.0
    expect(@test_obj.mem_usage_absolute_average({"backedPhysicalMem" => [1, 1], "logicalMem" => [10, 10]})).to eq 10.0
    expect(@test_obj.mem_usage_absolute_average({"backedPhysicalMem" => [0], "logicalMem" => [0]})).to be_nil
  end

  it "mem_usage_absolute_average_host" do
    expect(@test_obj.mem_usage_absolute_average_host({"assignedMemToLpars" => [5], "configurableMem" => [10]})).to eq 50.0
    expect(@test_obj.mem_usage_absolute_average_host({"assignedMemToLpars" => [1, 1], "configurableMem" => [10, 10]})).to eq 10.0
    expect(@test_obj.mem_usage_absolute_average_host({"assignedMemToLpars" => [0], "configurableMem" => [0]})).to be_nil
  end

  it "mem_usage_absolute_average_vios" do
    expect(@test_obj.mem_usage_absolute_average_vios({"utilizedMem" => [5], "assignedMem" => [10]})).to eq 50.0
    expect(@test_obj.mem_usage_absolute_average_vios({"utilizedMem" => [1, 1], "assignedMem" => [10, 10]})).to eq 10.0
    expect(@test_obj.mem_usage_absolute_average_vios({"utilizedMem" => [0], "assignedMem" => [0]})).to be_nil
  end

  let(:network_data) do
    {
      "adap_type1" => [
        {"transferredBytes" => [1024, 1024]},
        {"transferredBytes" => [1024, 2048]}
      ],
      "adap_type2" => [
        {"transferredBytes" => [20_480]},
        {"transferredBytes" => [20_480]}
      ]
    }
  end

  let(:network_data_host) do
    {
      "serverUtil" => {
        "network" => {
          "adap_type1" => [
            {
              "physicalPorts" => [
                {"transferredBytes" => [30_720, 30_720]},
                {"transferredBytes" => [30_720, 30_720]}
              ]
            }
          ],
          "adap_type2" => [
            {
              "physicalPorts" => [
                {"transferredBytes" => [30_720, 30_720]},
                {"transferredBytes" => [30_720, 30_720]}
              ]
            }
          ]
        }
      },
      "viosUtil"   => [
        {"network" => network_data},
        {"network" => network_data}
      ]
    }
  end

  it "net_usage_rate_average" do
    expect(@test_obj.net_usage_rate_average(network_data)).to eq 45.0
  end

  it "net_usage_rate_average_server" do
    expect(@test_obj.net_usage_rate_average_server(network_data_host["serverUtil"]["network"])).to eq 240.0
  end

  it "net_usage_rate_average_all_vios" do
    expect(@test_obj.net_usage_rate_average_all_vios(network_data_host)).to eq 90.0
  end

  describe "#safe_rate" do
    it "returns 100 * numerator / denominator for a normal case" do
      expect(@test_obj.safe_rate(5.0, 10.0)).to eq 50.0
    end

    it "returns nil when denominator is zero" do
      expect(@test_obj.safe_rate(5.0, 0.0)).to be_nil
    end

    it "returns correct result when denominator is a non-integer float (e.g. 0.5)" do
      expect(@test_obj.safe_rate(1.0, 0.5)).to eq 200.0
    end
  end

  it "interpolate_samples" do
    i = @test_obj.interpolate_samples(processed_samples)
    expect(i).to include(interpolated_samples)
    expect(i.count).to eq(5)
  end

  it "interpolate_samples (without first processed sample)" do
    i = @test_obj.interpolate_samples(processed_samples.reject { |k| k == ts })
    expect(i).to include(interpolated_samples.reject { |k| k < ts })
    expect(i.count).to eq(4)
  end

  it "interpolate_samples (without last processed sample)" do
    i = @test_obj.interpolate_samples(processed_samples.reject { |k| k == ts + described_class::SAMPLE_DURATION * 3 })
    expect(i).to include(interpolated_samples.select { |k| k <= ts + described_class::MIQ_SAMPLE_INTERVAL * 2 })
    expect(i.count).to eq(4)
  end

  it "interpolate_samples (gap in samples)" do
    i = @test_obj.interpolate_samples(processed_samples.reject { |k| k == ts + described_class::SAMPLE_DURATION })
    expect(i).to include(interpolated_samples.reject { |k| k >= ts && k <= ts + described_class::MIQ_SAMPLE_INTERVAL })
    expect(i.count).to eq(3)
  end

  it "interpolate_samples (empty processed sample set)" do
    expect(@test_obj.interpolate_samples({})).to be_empty
  end

  context "HMC sample timestamps are the end of the sample window" do
    let(:t0) { Time.utc(2026, 10, 22, 14, 0, 30) }
    let(:processed) do
      {
        t0                                        => {:cpu => 50},
        t0 + described_class::SAMPLE_DURATION     => {:cpu => 90},
        t0 + described_class::SAMPLE_DURATION * 2 => {:cpu => 100}
      }
    end

    it "stores each value at the start of the window it covers" do
      expect(@test_obj.interpolate_samples(processed)).to eq(
        Time.utc(2026, 10, 22, 14, 0, 0)  => {:cpu => 50},  # 14:00:00-14:00:30 -> sample 14:00:30
        Time.utc(2026, 10, 22, 14, 0, 20) => {:cpu => 70},  # 10s of 14:00:30 + 10s of 14:01:00
        Time.utc(2026, 10, 22, 14, 0, 40) => {:cpu => 90},  # 14:00:30-14:01:00 -> sample 14:01:00
        Time.utc(2026, 10, 22, 14, 1, 0)  => {:cpu => 100}  # 14:01:00-14:01:30 -> sample 14:01:30
      )
    end

    it "always produces timestamps on the 20s grid, whatever the first sample second is" do
      [0, 10, 30, 50].each do |first_second|
        first = Time.utc(2026, 10, 22, 14, 0, 0) + first_second
        samples = (0..6).to_h { |n| [first + described_class::SAMPLE_DURATION * n, {:cpu => n}] }

        timestamps = @test_obj.interpolate_samples(samples).keys
        expect(timestamps).not_to be_empty
        expect(timestamps.map(&:sec)).to all(satisfy { |sec| (sec % described_class::MIQ_SAMPLE_INTERVAL.to_i).zero? })
      end
    end

    it "does not shift when the timestamp is rounded by ManageIQ core" do
      timestamps = @test_obj.interpolate_samples(processed).keys
      expect(timestamps.map { |t| Metric::Helper.nearest_realtime_timestamp(t) }).to eq(timestamps.map { |t| t.utc.iso8601 })
    end
  end
end
