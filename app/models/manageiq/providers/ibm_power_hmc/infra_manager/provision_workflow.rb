class ManageIQ::Providers::IbmPowerHmc::InfraManager::ProvisionWorkflow < ManageIQ::Providers::InfraManager::ProvisionWorkflow
  def dialog_name_from_automate(message = 'get_dialog_name')
    $ibm_power_hmc_log.info("#{self.class}##{__method__}")
    super(message, {'platform' => 'ibm_power_hmc'})
  end

  def allowed_hosts_obj(_options = {})
    return [] if (src = resources_for_ui).blank? || src[:ems].nil?

    rails_logger('allowed_hosts_obj', 0)
    st = Time.zone.now
    hosts_ids = load_ar_obj(src[:ems]).hosts.joins(:advanced_settings).where(:advanced_settings => {:name => "hmc_managed", :value => "true"}).pluck(:id)
    hosts_ids &= load_ar_obj(src[:storage]).hosts.collect(&:id) unless src[:storage].nil?
    return [] if hosts_ids.blank?

    all_hosts = load_ar_obj(src[:ems]).hosts.where(:id => hosts_ids)
    allowed_hosts_obj_cache = process_filter(:host_filter, Host, all_hosts)
    _log.info("allowed_hosts_obj returned [#{allowed_hosts_obj_cache.length}] objects in [#{Time.zone.now - st}] seconds")
    rails_logger('allowed_hosts_obj', 1)
    allowed_hosts_obj_cache
  end

  def allowed_hosts(_options = {})
    allowed_hosts_obj.map do |h|
      host_to_hash_struct(h)
    end
  end

  # Extends the base ws_vm_fields to also process the :storage dialog tab,
  # which the core MiqProvisionVirtWorkflow does not iterate.
  # This allows API callers to pass vscsi_storage and vfc_storage in vm_fields.
  def ws_vm_fields(values, fields)
    super
    ws_storage_fields(values, fields)
  end

  def self.provider_model
    ManageIQ::Providers::IbmPowerHmc::InfraManager
  end

  private

  def ws_storage_fields(values, fields)
    return if (dlg_fields = get_ws_dialog_fields(:storage)).nil?

    data = parse_ws_string(fields)
    data.keys.each { |key| set_ws_field_value(values, key, data, :storage, dlg_fields) if dlg_fields.key?(key) }
  end
end
