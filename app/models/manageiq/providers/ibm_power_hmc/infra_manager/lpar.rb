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
    metrics = {}
    ext_management_system.with_provider_connection do |connection|
      samples = connection.lpar_metrics(
        :sys_uuid  => host.ems_ref,
        :lpar_uuid => ems_ref,
        :start_ts  => start_time,
        :end_ts    => end_time
      )
      samples.first["systemUtil"]["utilSamples"].each do |s|
        ts = Time.xmlschema(s["sampleInfo"]["timeStamp"])
        metrics[ts] = {}
        counters.each_key do |key|
          metrics[ts][key] =
            case key
            when "cpu_usage_rate_average"
              cpu_usage_rate_average(s["lparsUtil"].first["processor"])
            when "disk_usage_rate_average"
              disk_usage_rate_average(s["lparsUtil"].first["storage"])
            when "mem_usage_absolute_average"
              mem_usage_absolute_average(s["lparsUtil"].first["memory"])
            when "net_usage_rate_average"
              net_usage_rate_average(s["lparsUtil"].first["network"])
            end
        end
      end
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error getting performance samples for LPAR #{ems_ref}: #{e}")
      unless e.msg.eql?("403 Forbidden") # TO DO - Capture should be disabled at Host level if PCM is not enabled
        raise
      end
    end
    metrics
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
end
