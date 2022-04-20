module ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCaptureMixin
  SAMPLE_DURATION     = 30.seconds
  MIQ_SAMPLE_INTERVAL = 20.seconds

  def capture_metrics(counters, start_time = nil, end_time = nil)
    samples = collect_samples(start_time, end_time)
    processed = process_samples(counters, samples)
    interpolate_samples(processed, SAMPLE_DURATION, MIQ_SAMPLE_INTERVAL)
  end

  def cpu_usage_rate_average(sample)
    100.0 * sample["utilizedProcUnits"].sum / sample["entitledProcUnits"].sum
  end

  def cpu_usage_rate_average_host(sample)
    100.0 * sample["utilizedProcUnits"].sum / sample["configurableProcUnits"].sum
  end

  def disk_usage_rate_average(sample)
    usage = sample.values.sum do |adapters|
      adapters.sum do |adapter|
        adapter["readBytes"].sum + adapter["writeBytes"].sum
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
    safe_rate(sample["backedPhysicalMem"].sum, sample["logicalMem"].sum)
  end

  def mem_usage_absolute_average_host(sample)
    safe_rate(sample["assignedMemToLpars"].sum, sample["configurableMem"].sum)
  end

  def mem_usage_absolute_average_vios(sample)
    safe_rate(sample["utilizedMem"].sum, sample["assignedMem"].sum)
  end

  def net_usage_rate_average(sample)
    usage = sample.values.sum do |adapters|
      adapters.sum do |adapter|
        adapter["transferredBytes"].sum
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def net_usage_rate_average_server(sample)
    usage = sample.values.sum do |adapters|
      adapters.sum do |adapter|
        adapter["physicalPorts"].sum do |phys_port|
          phys_port["transferredBytes"].sum
        end
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def net_usage_rate_average_vios(sample)
    usage = sample.values.sum do |adapters|
      adapters.select { |a| a.kind_of?(Hash) }.sum do |adapter|
        adapter["transferredBytes"].sum
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

  def safe_rate(numerator, denominator)
    unless denominator.to_i == 0
      100.0 * numerator / denominator
    end
  end

  def interpolate_samples(processed, old_interval, new_interval)
    interpolated = {}
    timestamps = processed.keys.sort
    t = timestamps.first
    while t < timestamps.last + old_interval
      selected = timestamps.select { |ts| ts + old_interval > t && ts < t + new_interval }.map do |ts|
        if ts < t
          {:ts => ts, :weight => old_interval - (t - ts)}
        elsif ts + old_interval > t + new_interval
          {:ts => ts, :weight => t + new_interval - ts}
        else
          {:ts => ts, :weight => old_interval}
        end
      end
      interpolated[t] = selected.map { |s| processed[s[:ts]].keys }.inject(:&).index_with do |counter|
        selected.map { |s| processed[s[:ts]][counter] * s[:weight] }.sum / new_interval
      end
      t += new_interval
    end
    interpolated
  end
end
