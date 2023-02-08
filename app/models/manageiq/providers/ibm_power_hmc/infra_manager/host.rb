class ManageIQ::Providers::IbmPowerHmc::InfraManager::Host < ::Host
  include ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCaptureMixin

  supports :update
  supports :capture do
    unsupported_reason_add(:capture, _("PCM not enabled for this Host")) unless pcm_enabled
  end

  supports :stop do
    unsupported_reason_add(:stop, _("Cannot shutdown a host that is powered off")) unless power_state == "on"
    unsupported_reason_add(:stop, _("Cannot shutdown a host that is not HMC-managed")) unless hmc_managed
  end

  supports :shutdown do
    unsupported_reason_add(:shutdown, _("Cannot shutdown a host that is powered off")) unless power_state == "on"
    unsupported_reason_add(:shutdown, _("Cannot shutdown a host with running vms")) if vms.where(:power_state => "on").any?
    unsupported_reason_add(:shutdown, _("Cannot shutdown a host that is not HMC-managed")) unless hmc_managed
  end

  supports :start do
    unsupported_reason_add(:start, _("Cannot start a host that is already powered on")) unless power_state == "off"
    unsupported_reason_add(:start, _("Cannot start a host that is not HMC-managed")) unless hmc_managed
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

  def hmc_managed
    as = advanced_settings.detect { |s| s.name == "hmc_managed" }
    if as.nil?
      false
    else
      ActiveRecord::Type::Boolean.new.cast(as.value)
    end
  end

  virtual_column :pcm_enabled, :type => :boolean, :uses => :advanced_settings
  virtual_column :hmc_managed, :type => :boolean, :uses => :advanced_settings

  # Display or hide certain performance charts
  def cpu_mhz_available?
    false
  end

  def cpu_ready_available?
    false
  end

  def cpu_percent_available?
    true
  end

  def self.display_name(number = 1)
    n_("Managed System", "Managed Systems", number)
  end

  def params_for_update
    {
      :fields => [
        {
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _("Endpoints"),
          :fields    => [
            :component => 'tabs',
            :name      => 'tabs',
            :fields    => [
              {
                :component => 'tab-item',
                :id        => 'default-tab',
                :name      => 'default-tab',
                :title     => _('Default'),
                :fields    => [
                  {
                    :component  => 'validate-host-credentials',
                    :id         => 'endpoints.default.valid',
                    :name       => 'endpoints.default.valid',
                    :skipSubmit => true,
                    :isRequired => true,
                    :fields     => [
                      {
                        :component  => "text-field",
                        :id         => "authentications.default.userid",
                        :name       => "authentications.default.userid",
                        :label      => _("Username"),
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                      },
                      {
                        :component  => "password-field",
                        :id         => "authentications.default.password",
                        :name       => "authentications.default.password",
                        :label      => _("Password"),
                        :type       => "password",
                        :isRequired => true,
                        :validate   => [{:type => "required"}],
                      },
                    ],
                  },
                ],
              },
            ]
          ]
        },
      ]
    }
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
