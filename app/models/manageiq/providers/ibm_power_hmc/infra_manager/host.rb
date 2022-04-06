class ManageIQ::Providers::IbmPowerHmc::InfraManager::Host < ::Host
  def capture_metrics(counters, start_time = nil, end_time = nil)
    samples = collect_samples(start_time, end_time)
    process_samples(counters, samples)
  end

  private

  SAMPLE_DURATION = 30.0 # seconds

  def cpu_usage_rate_average(sample)
    100.0 * sample["utilizedProcUnits"].sum / sample["configurableProcUnits"].sum
  end

  def disk_usage_rate_average_vios(sample)
    usage = 0.0
    sample.each do |_adapter_type, adapters|
      adapters.select { |a| a.kind_of?(Hash) }.each do |adapter|
        usage += adapter["transmittedBytes"].sum
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def disk_usage_rate_average_all_vios(sample)
    sample["viosUtil"].sum do |vios|
      if vios["storage"]
        disk_usage_rate_average_vios(vios["storage"])
      else
        0.0
      end
    end
  end

  def mem_usage_absolute_average(sample)
    100.0 * sample["assignedMemToLpars"].sum / sample["configurableMem"].sum
  end

  def net_usage_rate_average_server(sample)
    usage = 0.0
    sample.each do |_adapter_type, adapters|
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
    sample.each do |_adapter_type, adapters|
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

  def get_sample_value(sample, key)
    r = nil
    case key
    when "cpu_usage_rate_average"
      if sample["serverUtil"]["processor"]
        r = cpu_usage_rate_average(sample["serverUtil"]["processor"])
      end
    when "disk_usage_rate_average"
      r = disk_usage_rate_average_all_vios(sample)
    when "mem_usage_absolute_average"
      if sample["serverUtil"]["memory"]
        mem_usage_absolute_average(sample["serverUtil"]["memory"])
      end
    when "net_usage_rate_average"
      if sample["serverUtil"]["network"]
        r = net_usage_rate_average_server(sample["serverUtil"]["network"]) +
            net_usage_rate_average_all_vios(sample)
      end
    end
    r
  end

  def collect_samples(start_time, end_time)
    ext_management_system.with_provider_connection do |connection|
      connection.managed_system_metrics(
        :sys_uuid => ems_ref,
        :start_ts => start_time,
        :end_ts   => end_time
      )
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error getting performance samples for host #{ems_ref}: #{e}")
      unless e.message.eql?("403 Forbidden") # TO DO - Capture should be disabled at Host level if PCM is not enabled
        raise
      end

      []
    end
  end

  def process_samples(counters, samples)
    metrics = {}
    samples.dig(0, "systemUtil", "utilSamples")&.each do |s|
      ts = Time.xmlschema(s["sampleInfo"]["timeStamp"])
      metrics[ts] = {}
      counters.each_key do |key|
        val = get_sample_value(s, key)
        metrics[ts][key] = val unless val.nil?
      end
    end
    metrics
  end
end
