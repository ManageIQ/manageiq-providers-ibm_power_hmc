module ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCaptureMixin
  SAMPLE_DURATION = 30.0 # seconds

  def capture_metrics(counters, start_time = nil, end_time = nil)
    samples = collect_samples(start_time, end_time)
    process_samples(counters, samples)
  end

  def cpu_usage_rate_average(sample)
    100.0 * sample["utilizedProcUnits"].sum / sample["entitledProcUnits"].sum
  end

  def cpu_usage_rate_average_host(sample)
    100.0 * sample["utilizedProcUnits"].sum / sample["configurableProcUnits"].sum
  end

  def disk_usage_rate_average(sample)
    usage = 0.0
    sample.each do |_adapter_type, adapters|
      adapters.each do |adapter|
        usage += adapter["readBytes"].sum + adapter["writeBytes"].sum
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def disk_usage_rate_average_vios(sample)
    usage = sample.values.sum do |adapters|
      adapters.select { |a| a.kind_of?(Hash) }.sum { |adapter| adapter["transmittedBytes"]&.sum || 0.0 }
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def disk_usage_rate_average_all_vios(sample)
    sample["viosUtil"]&.sum { |vios| vios.key?("storage") ? disk_usage_rate_average_vios(vios["storage"]) : 0.0 }.to_f
  end

  def mem_usage_absolute_average(sample)
    a = sample["backedPhysicalMem"].sum
    c = sample["logicalMem"].sum
    c == 0.0 ? nil : 100.0 * a / c
  end

  def mem_usage_absolute_average_host(sample)
    a = sample["assignedMemToLpars"].sum
    c = sample["configurableMem"].sum
    c == 0.0 ? nil : 100.0 * a / c
  end

  def mem_usage_absolute_average_vios(sample)
    a = sample["utilizedMem"].sum
    c = sample["assignedMem"].sum
    c == 0.0 ? nil : 100.0 * a / c
  end

  def net_usage_rate_average(sample)
    usage = 0.0
    sample.each do |_adapter_type, adapters|
      adapters.each do |adapter|
        usage += adapter["sentBytes"].sum + adapter["receivedBytes"].sum
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def net_usage_rate_average_server(sample)
    usage = 0.0
    sample.each_value do |adapters|
      adapters.each do |adapter|
        adapter["physicalPorts"].each do |phys_port|
          usage += phys_port["transferredBytes"].sum
        end
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def net_usage_rate_average_vios(sample)
    usage = 0.0
    sample.each_value do |adapters|
      adapters.select { |a| a.kind_of?(Hash) }.each do |adapter|
        usage += adapter["transferredBytes"].sum
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def net_usage_rate_average_all_vios(sample)
    sample["viosUtil"].sum do |vios|
      if vios["network"]
        net_usage_rate_average_vios(vios["network"])
      else
        0.0
      end
    end
  end
end
