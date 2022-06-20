class ManageIQ::Providers::IbmPowerHmc::InfraManager::Template < ManageIQ::Providers::InfraManager::Template
  supports :provisioning

  def provision_lpar(options)
    $ibm_power_hmc_log.info("#{self.class}##{__method__} template_name #{name} lpar name #{lpar_name}")
    ext_management_system.with_provider_connection do |connection|
      check_job = connection.template_check(ems_ref, options[:target_sys_uuid])
      draft_uuid = check_job.results["TEMPLATE_UUID"]

      connection.template_modify(draft_uuid, {:lpar_name => options[:name]})

      transform_job = connection.template_transform(draft_uuid, options[:target_sys_uuid])
      # transform_job.last_status == "COMPLETED_OK"

      deploy_job = connection.template_deploy_lpar(ems_ref, name, lpar_name)
      # @results={"DeployBasePartition"=>"COMPLETED_OK", "PartitionUuid"=>"642B5E86-7C43-4B21-9C26-DADA8B461A9A", "DeployingNetwork"=>"COMPLETED_OK"}
      deploy_job.results["PartitionUuid"]
    rescue IbmPowerHmc::Connection::HttpError => e
      $ibm_power_hmc_log.error("error creating LPAR #{lpar_name} from template #{name}: #{e}")
      raise
    end
  end
end
