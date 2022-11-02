class ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios < ManageIQ::Providers::IbmPowerHmc::InfraManager::Vm
  def provider_object(connection = nil)
    connection ||= ext_management_system.connect
    connection.vios(ems_ref)
  end

  def console_url
    URI::HTTPS.build(:host => ext_management_system.hostname, :path => "/dashboard/", :fragment => "resources/systems/#{host.ems_ref}/virtual-i-o-servers")
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

  def collect_samples(start_time, end_time)
    ext_management_system.with_provider_connection do |connection|
      connection.managed_system_metrics(
        :sys_uuid => host.ems_ref,
        :start_ts => start_time,
        :end_ts   => end_time
      )
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error getting performance samples for host #{ems_ref}: #{e}")
      raise unless e.message.eql?("403 Forbidden") # TO DO - Capture should be disabled at Host level if PCM is not enabled

      []
    end
  end

  def process_samples(counters, samples)
    samples.dig(0, "systemUtil", "utilSamples")&.each_with_object({}) do |s, metrics|
      vios_sample = s["viosUtil"]&.find { |vios| vios["uuid"].eql?(ems_ref) }
      next if vios_sample.nil?

      ts = Time.xmlschema(s["sampleInfo"]["timeStamp"])
      metrics[ts] = counters.each_key.map do |key|
        val = get_sample_value(vios_sample, key)
        next if val.nil?

        [key, val]
      end.compact.to_h
    end || {}
  end

  def self.display_name(number = 1)
    n_("Virtual I/O Server", "Virtual I/O Servers", number)
  end

  private

  def get_sample_value(sample, key)
    case key
    when "cpu_usage_rate_average"
      if sample["processor"]
        cpu_usage_rate_average(sample["processor"])
      end
    when "disk_usage_rate_average"
      if sample["storage"]
        disk_usage_rate_average_vios(sample["storage"])
      end
    when "mem_usage_absolute_average"
      if sample["memory"]
        mem_usage_absolute_average_vios(sample["memory"])
      end
    when "net_usage_rate_average"
      if sample["network"]
        net_usage_rate_average(sample["network"])
      end
    end
  end
end
