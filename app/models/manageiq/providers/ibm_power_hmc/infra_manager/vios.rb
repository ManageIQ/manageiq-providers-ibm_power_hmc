class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios < ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.vios(ems_ref)
  end

  def poweron(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweron_vios(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering on VIOS #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end

  def poweroff(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweroff_vios(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering off VIOS #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end

  def make_template(_clone_options)
    raise StandardError, "Cannot create a template from a VIOS"
  end

  def capture_metrics(counters, start_time = nil, end_time = nil)
    samples = collect_samples(start_time, end_time)
    process_samples(counters, samples)
  end

  private

  SAMPLE_DURATION = 30.0 # seconds

  def cpu_usage_rate_average(sample)
    100.0 * sample["utilizedProcUnits"].sum / sample["entitledProcUnits"].sum
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

  def mem_usage_absolute_average_vios(sample)
    100.0 * sample["utilizedMem"].sum / sample["assignedMem"].sum
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

  def get_sample_value(sample, key)
    r = nil
    case key
    when "cpu_usage_rate_average"
      if sample["processor"]
        r = cpu_usage_rate_average(sample["processor"])
      end
    when "disk_usage_rate_average"
      if sample["storage"]
        r = disk_usage_rate_average_vios(sample["storage"])
      end
    when "mem_usage_absolute_average"
      if sample["memory"]
        r = mem_usage_absolute_average_vios(sample["memory"])
      end
    when "net_usage_rate_average"
      if sample["network"]
        r = net_usage_rate_average_vios(sample["network"])
      end
    end
    r
  end

  def collect_samples(start_time, end_time)
    ext_management_system.with_provider_connection do |connection|
      connection.managed_system_metrics(
        :sys_uuid => host.ems_ref,
        :start_ts => start_time,
        :end_ts   => end_time
      )
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error getting performance samples for host #{ems_ref}: #{e}")
      unless e.msg.eql?("403 Forbidden") # TO DO - Capture should be disabled at Host level if PCM is not enabled
        raise
      end

      []
    end
  end

  def process_samples(counters, samples)
    metrics = {}
    samples.dig(0, "systemUtil", "utilSamples")&.each do |s|
      vios_sample = s["viosUtil"].find { |vios| vios["uuid"].eql?(ems_ref) }
      next if vios_sample.nil?

      ts = Time.xmlschema(s["sampleInfo"]["timeStamp"])
      metrics[ts] = {}
      counters.each_key do |key|
        val = get_sample_value(vios_sample, key)
        metrics[ts][key] = val unless val.nil?
      end
    end
    metrics
  end
end
