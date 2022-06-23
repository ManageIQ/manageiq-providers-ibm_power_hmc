class ManageIQ::Providers::IbmPowerHmc::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  supports :provisioning

  def provision_lpar(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} lpar name #{options[:name]}")
    ext_management_system.with_provider_connection do |connection|

      check_job = connection.template_check(ems_ref, options[:target_sys_uuid])
      draft_uuid = check_job.results["TEMPLATE_UUID"]
      $ibm_power_hmc_log.info("STEP1: #{name}->#{options[:name]}/#{options[:target_sys_uuid]} Checked #{draft_uuid} (#{check_job.inspect})")

      transform_job = connection.template_transform(draft_uuid, options[:target_sys_uuid])
      # transform_job.last_status == "COMPLETED_OK"
      $ibm_power_hmc_log.info("STEP2: #{name}->#{options[:name]}/#{options[:target_sys_uuid]} Transformed #{transform_job.last_status} (#{transform_job.inspect})")

      connection.template_modify(draft_uuid, {:lpar_name => options[:name]})
      connection.template_modify(draft_uuid, {:lpar_id => nil})

      deploy_job = connection.template_deploy(draft_uuid, options[:target_sys_uuid])
      # @results={"DeployBasePartition"=>"COMPLETED_OK", "PartitionUuid"=>"642B5E86-7C43-4B21-9C26-DADA8B461A9A", "DeployingNetwork"=>"COMPLETED_OK"}
      $ibm_power_hmc_log.info("STEP3: #{name}->#{options[:name]}/#{options[:target_sys_uuid]} Deployed #{deploy_job.last_status} [#{deploy_job.results["PartitionUuid"]}] (#{deploy_job.inspect})")
      deploy_job.results["PartitionUuid"]
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error creating LPAR #{options[:name]} from template #{name}: #{e}")
      raise
    end
  end
end
