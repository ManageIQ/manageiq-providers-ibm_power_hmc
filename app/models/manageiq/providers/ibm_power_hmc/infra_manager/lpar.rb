class ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar < ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm
  supports :rename

  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.lpar(ems_ref)
  end

  def poweron(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweron_lpar(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering on LPAR #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end

  def poweroff(params = {})
    ext_management_system.with_provider_connection do |connection|
      connection.poweroff_lpar(ems_ref, params)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering off LPAR #{ems_ref} with params=#{params}: #{e}")
      raise
    end
  end

  def raw_rename(new_name)
    ext_management_system.with_provider_connection do |connection|
      connection.rename_lpar(ems_ref, new_name)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error renaming LPAR #{ems_ref} to #{new_name}: #{e}")
      raise
    end
  end

  def make_template(template_name)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} ems_ref #{ems_ref} template_name #{template_name}")
    ext_management_system.with_provider_connection do |connection|
      connection.capture_lpar(ems_ref, host.ems_ref, template_name)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error creating template #{template_name} from LPAR #{ems_ref}: #{e}")
      raise
    end
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

  def disk_usage_rate_average(sample)
    usage = 0.0
    sample.each do |_adapter_type, adapters|
      adapters.each do |adapter|
        usage += adapter["readBytes"].sum + adapter["writeBytes"].sum
      end
    end
    usage / SAMPLE_DURATION / 1.0.kilobyte
  end

  def mem_usage_absolute_average(sample)
    100.0 * sample["backedPhysicalMem"].sum / sample["logicalMem"].sum
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

  def get_sample_value(sample, key)
    r = nil
    case key
    when "cpu_usage_rate_average"
      if sample["lparsUtil"].first["processor"]
        cpu_usage_rate_average(sample["lparsUtil"].first["processor"])
      end
    when "disk_usage_rate_average"
      if sample["lparsUtil"].first["storage"]
        disk_usage_rate_average(sample["lparsUtil"].first["storage"])
      end
    when "mem_usage_absolute_average"
      if sample["lparsUtil"].first["memory"]
        mem_usage_absolute_average(sample["lparsUtil"].first["memory"])
      end
    when "net_usage_rate_average"
      if sample["lparsUtil"].first["network"]
        net_usage_rate_average(sample["lparsUtil"].first["network"])
      end
    end
    r
  end

  def collect_samples(start_time, end_time)
    ext_management_system.with_provider_connection do |connection|
      connection.lpar_metrics(
        :sys_uuid  => host.ems_ref,
        :lpar_uuid => ems_ref,
        :start_ts  => start_time,
        :end_ts    => end_time
      )
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error getting performance samples for LPAR #{ems_ref}: #{e}")
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
  end
end
