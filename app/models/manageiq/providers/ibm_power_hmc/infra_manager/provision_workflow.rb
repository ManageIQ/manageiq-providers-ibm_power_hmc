class ManageIQ::Providers::IbmPowerHmc::InfraManager::ProvisionWorkflow < ManageIQ::Providers::InfraManager::ProvisionWorkflow
  def dialog_name_from_automate(message = 'get_dialog_name')
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    super(message, {'platform' => 'ibm_power_hmc'})
  end

  def allowed_hosts_obj(options = {})
    return [] if (src = resources_for_ui).blank? || src[:ems].nil?
    #datacenter = src[:datacenter] || options[:datacenter]
    rails_logger('allowed_hosts_obj', 0)
    st = Time.now
    #hosts_ids = find_all_ems_of_type(Host).collect(&:id)
    hosts_ids = load_ar_obj(src[:ems]).hosts.pluck(:id)
    hosts_ids &= load_ar_obj(src[:storage]).hosts.collect(&:id) unless src[:storage].nil?
    #if datacenter
    #  @_allowed_hosts_obj_prefix ||= _log.prefix
    #  dc_node = load_ems_node(datacenter, @_allowed_hosts_obj_prefix)
    #  hosts_ids &= find_hosts_under_ci(dc_node.attributes[:object]).collect(&:id)
    #end
    return [] if hosts_ids.blank?

    # Remove any hosts that are no longer in the list
    all_hosts = load_ar_obj(src[:ems]).hosts.where(:id => hosts_ids)
    allowed_hosts_obj_cache = process_filter(:host_filter, Host, all_hosts)
    _log.info("allowed_hosts_obj returned [#{allowed_hosts_obj_cache.length}] objects in [#{Time.now - st}] seconds")
    rails_logger('allowed_hosts_obj', 1)
    allowed_hosts_obj_cache
  end
end
