module ManageIQ
  module Providers
    module IbmPowerHmc
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::IbmPowerHmc

        config.autoload_paths << root.join('lib').to_s

        initializer :append_secrets do |app|
          app.config.paths["config/secrets"] << root.join("config", "secrets.defaults.yml").to_s
          app.config.paths["config/secrets"] << root.join("config", "secrets.yml").to_s
        end

        def self.vmdb_plugin?
          true
        end

        def self.plugin_name
          _('Ibm Power Hmc Provider')
        end

        def self.init_loggers
          $ibm_power_hmc_log ||= Vmdb::Loggers.create_logger("ibm_power_hmc.log")
        end

        def self.apply_logger_config(config)
          Vmdb::Loggers.apply_config_value(config, $ibm_power_hmc_log, :level_ibm_power_hmc)
        end
      end
    end
  end
end
