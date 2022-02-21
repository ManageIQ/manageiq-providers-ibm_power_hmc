class ManageIQ::Providers::IbmPowerHmc::InfraManager::MetricsCapture < ManageIQ::Providers::InfraManager::MetricsCapture
  VIM_STYLE_COUNTERS = {
    "cpu_usage_rate_average"     => {
      :counter_key           => "cpu_usage_rate_average",
      :instance              => "",
      :capture_interval      => "30",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },
    "disk_usage_rate_average"    => {
      :counter_key           => "disk_usage_rate_average",
      :instance              => "",
      :capture_interval      => "30",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    },
    "mem_usage_absolute_average" => {
      :counter_key           => "mem_usage_absolute_average",
      :instance              => "",
      :capture_interval      => "30",
      :precision             => 1,
      :rollup                => "average",
      :unit_key              => "percent",
      :capture_interval_name => "realtime"
    },
    "net_usage_rate_average"     => {
      :counter_key           => "net_usage_rate_average",
      :instance              => "",
      :capture_interval      => "30",
      :precision             => 2,
      :rollup                => "average",
      :unit_key              => "kilobytespersecond",
      :capture_interval_name => "realtime"
    }
  }.freeze

  def perf_collect_metrics(interval_name, start_time = nil, end_time = nil)
    raise "No EMS defined" if target.ext_management_system.nil?

    log_header = "[#{interval_name}] for: [#{target.class.name}], [#{target.id}], [#{target.name}]"

    end_time ||= Time.zone.now
    end_time = end_time.utc
    start_time ||= end_time - 4.hours # 4 hours for symmetry with VIM
    start_time   = start_time.utc

    begin
      [
        {target.ems_ref => VIM_STYLE_COUNTERS},
        {target.ems_ref => target.capture_metrics(VIM_STYLE_COUNTERS, start_time, end_time)}
      ]
    rescue => err
      _log.error("#{log_header} Unhandled exception during perf data collection: [#{err}], class: [#{err.class}]")
      _log.error("#{log_header}   Timings at time of error: #{Benchmark.current_realtime.inspect}")
      _log.log_backtrace(err)
      raise
    end
  end
end
