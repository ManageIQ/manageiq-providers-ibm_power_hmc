class ManageIQ::Providers::IbmPowerHmc::InfraManager::Host < ::Host
  def capture_metrics(counters, start_time = nil, end_time = nil)
    metrics = {}
    ext_management_system.with_provider_connection do |connection|
      samples = connection.managed_system_metrics(
        :sys_uuid => ems_ref,
        :start_ts => start_time,
        :end_ts   => end_time
      )
      samples.first["systemUtil"]["utilSamples"].each do |s|
        ts = Time.xmlschema(s["sampleInfo"]["timeStamp"])
        metrics[ts] = {}
        counters.each_key do |key|
          metrics[ts][key] =
            case key
            when "cpu_usage_rate_average"
              cpu_usage_rate_average(s["serverUtil"]["processor"])
            when "disk_usage_rate_average"
              s["viosUtil"].sum do |vios|
                disk_usage_rate_average_vios(vios["storage"])
              end
            when "mem_usage_absolute_average"
              mem_usage_absolute_average(s["serverUtil"]["memory"])
            when "net_usage_rate_average"
              net_usage_rate_average_server(s["serverUtil"]["network"]) +
              s["viosUtil"].sum do |vios|
                net_usage_rate_average_vios(vios["network"])
              end
            end
        end
      end
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error getting performance samples for host #{ems_ref}: #{e}")
      unless e.msg.eql?("403 Forbidden") # TO DO - Capture should be disabled at Host level if PCM is not enabled
        raise
      end
    end
    metrics
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
end
