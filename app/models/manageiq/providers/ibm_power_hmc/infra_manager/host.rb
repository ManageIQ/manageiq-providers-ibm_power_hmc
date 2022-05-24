class ManageIQ::Providers::IbmPowerHmc::InfraManager::Host < ::Host
  include ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCaptureMixin

  supports :capture do
    unsupported_reason_add(:capture, _("PCM not enabled for this Host")) unless pcm_enabled
  end

  supports :stop
  supports :shutdown

  def validate_stop
    message = _("Cannot shutdown a host that is powered off") if power_state == "off"

    {:available => message.nil?, :message => message}
  end

  def validate_shutdown
    message = _("Cannot shutdown a host that is powered off") if power_state == "off"
    message = _("Cannot shutdown a host with running vms")    if vms.where(:power_state => "on").any?

    {:available => message.nil?, :message => message}
  end

  def validate_start
    message = _("Cannot start a host that is already powered on") if power_state == "on"

    {:available => message.nil?, :message => message}
  end

  def shutdown
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    ext_management_system.with_provider_connection do |connection|
      connection.poweroff_managed_system(ems_ref)
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering off managed system #{ems_ref}:  #{e}")
      raise
    end
  end

  def start
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    ext_management_system.with_provider_connection do |connection|
      connection.poweron_managed_system(ems_ref, {"operation" => "on"})
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error starting managed system #{ems_ref}:  #{e}")
    end
  end

  def stop
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    ext_management_system.with_provider_connection do |connection|
      connection.poweroff_managed_system(ems_ref, {"immediate" => "true"})
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error powering off managed system #{ems_ref}:  #{e}")
    end
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
      raise unless e.message.eql?("403 Forbidden") # TO DO - Capture should be disabled at Host level if PCM is not enabled

      []
    end
  end

  def process_samples(counters, samples)
    samples.dig(0, "systemUtil", "utilSamples")&.each_with_object({}) do |s, metrics|
      ts = Time.xmlschema(s["sampleInfo"]["timeStamp"])
      metrics[ts] = counters.each_key.map do |key|
        val = get_sample_value(s, key)
        next if val.nil?

        [key, val]
      end.compact.to_h
    end || {}
  end

  def pcm_enabled
    as = advanced_settings.detect { |s| s.name == "pcm_enabled" }
    if as.nil?
      false
    else
      ActiveRecord::Type::Boolean.new.cast(as.value)
    end
  end

  virtual_column :pcm_enabled, :type => :boolean, :uses => :advanced_settings
  
  def vms_off
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
  # def vms_off
  #   $ibm_power_hmc_log.info("#{self.class}##{__method__}")

  #   vms.each { |vm| return false unless vm.power_state.eql?("off") }

  #   return true
  # end
  end

  private

  def get_sample_value(sample, key)
    case key
    when "cpu_usage_rate_average"
      s = sample.dig("serverUtil", "processor")
      unless s.nil?
        cpu_usage_rate_average_host(s)
      end
    when "disk_usage_rate_average"
      disk_usage_rate_average_all_vios(sample)
    when "mem_usage_absolute_average"
      s = sample.dig("serverUtil", "memory")
      unless s.nil?
        mem_usage_absolute_average_host(s)
      end
    when "net_usage_rate_average"
      s = sample.dig("serverUtil", "network")
      if s
        net_usage_rate_average_server(s) +
          net_usage_rate_average_all_vios(sample)
      end
    end
  end
end
