class ManageIQ::Providers::IbmPowerHmc::InfraManager < ManageIQ::Providers::InfraManager
  supports :catalog
  supports :create
  supports :metrics
  supports :native_console
  supports :provisioning

  belongs_to :parent_manager,
             :class_name  => "ManageIQ::Providers::IbmPowerVc::CloudManager",
             :foreign_key => :parent_ems_id,
             :inverse_of  => :ibm_power_hmcs,
             :autosave    => true

  has_many :hosts_advanced_settings, :through => :hosts, :source => :advanced_settings
  has_many :media_repositories, :foreign_key => :ems_id, :dependent => :destroy, :inverse_of => :ext_management_system
  has_many :iso_images, :through => :media_repositories

  def self.params_for_create
    {
      :fields => [
        {
          :component => 'sub-form',
          :id        => 'endpoints-subform',
          :name      => 'endpoints-subform',
          :title     => _('Endpoints'),
          :fields    => [
            {
              :component              => 'validate-provider-credentials',
              :id                     => 'authentications.default.valid',
              :name                   => 'authentications.default.valid',
              :skipSubmit             => true,
              :isRequired             => true,
              :validationDependencies => %w[type zone_id parent_ems_id],
              :fields                 => [
                {
                  :component   => "select",
                  :id          => "parent_ems_id",
                  :name        => "parent_ems_id",
                  :label       => _("IBM PowerVC Cloud Provider"),
                  :isClearable => true,
                  :simpleValue => true,
                  :options     => parent_ems_id_options
                },
                {
                  :component    => "select",
                  :id           => "endpoints.default.security_protocol",
                  :name         => "endpoints.default.security_protocol",
                  :label        => _("Security Protocol"),
                  :isRequired   => true,
                  :initialValue => "ssl-with-validation",
                  :validate     => [{:type => "required"}],
                  :options      => [
                    {
                      :label => _("SSL without validation"),
                      :value => "ssl-no-validation"
                    },
                    {
                      :label => _("SSL"),
                      :value => "ssl-with-validation"
                    }
                  ]
                },
                {
                  :component  => "text-field",
                  :id         => "endpoints.default.hostname",
                  :name       => "endpoints.default.hostname",
                  :label      => _("Hostname (or IPv4 or IPv6 address)"),
                  :isRequired => true,
                  :validate   => [{:type => "required"}],
                },
                {
                  :component    => "text-field",
                  :id           => "endpoints.default.port",
                  :name         => "endpoints.default.port",
                  :label        => _("API Port"),
                  :type         => "number",
                  :initialValue => 443,
                  :isRequired   => true,
                  :validate     => [{:type => "required"}],
                },
                {
                  :component    => "text-field",
                  :id           => "authentications.default.userid",
                  :name         => "authentications.default.userid",
                  :label        => "Username",
                  :initialValue => "hscroot",
                  :isRequired   => true,
                  :validate     => [{:type => "required"}],
                },
                {
                  :component  => "password-field",
                  :id         => "authentications.default.password",
                  :name       => "authentications.default.password",
                  :label      => "Password",
                  :type       => "password",
                  :isRequired => true,
                  :validate   => [{:type => "required"}],
                },
              ]
            }
          ]
        }
      ]
    }
  end

  private_class_method def self.parent_ems_id_options
    t = ManageIQ::Providers::IbmPowerVc::CloudManager
    Rbac
      .filtered(t.order(t.arel_table[:name].lower))
      .pluck(:name, :id)
      .map do |name, id|
        {
          :label => name,
          :value => id.to_s,
        }
      end
  end

  def self.verify_credentials(args)
    endpoint = args.dig("endpoints", "default")
    security_protocol, hostname, port = endpoint&.values_at("security_protocol", "hostname", "port")
    validate_ssl = security_protocol == "ssl-with-validation"

    authentication = args.dig("authentications", "default")
    userid, password = authentication&.values_at("userid", "password")
    password = ManageIQ::Password.try_decrypt(password)
    password ||= find(args["id"]).authentication_password("default") if args['id']

    !!raw_connect(hostname, port, userid, password, validate_ssl, true)
  end

  def verify_credentials(_auth_type = nil, _options = {})
    begin
      connection = connect(:validate => true)
      fetch_and_store_hmc_version(connection)
      update_dashboard_capability
    rescue => err
      raise MiqException::MiqInvalidCredentialsError, err.message
    end

    true
  end

  def connect(options = {})
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(options[:auth_type])

    validate_ssl = security_protocol == "ssl-with-validation"
    userid = authentication_userid(options[:auth_type])
    password = authentication_password(options[:auth_type])

    options[:validate] ||= false

    self.class.raw_connect(hostname, port, userid, password, validate_ssl, options[:validate])
  end

  def disconnect(connection)
    connection.logoff
  end

  def self.raw_connect(hostname, port, userid, password, validate_ssl, validate)
    require "ibm_power_hmc"

    hc = IbmPowerHmc::Connection.new(
      :host         => hostname,
      :port         => port,
      :username     => userid,
      :password     => password,
      :validate_ssl => validate_ssl,
      :timeout      => Settings.ems.ems_ibm_power_hmc.api_request_timeout
    )
    if validate
      # Do a logon/logoff to verify credentials
      hc.logon
      hc.logoff
    end

    hc
  end

  def console_url
    dashboard_path = use_legacy_dashboard? ? "dashboard" : "newdashboard"
    "https://#{hostname}/#{dashboard_path}/"
  end

  def update_dashboard_capability
    if api_version.present?
      begin
        current_version = parse_hmc_version(api_version)
        threshold_version = parse_hmc_version("V10R2 1020")
        legacy_dashboard = current_version <= threshold_version
      rescue ArgumentError
        $ibm_power_hmc_log.warn("Failed to parse HMC version '#{hmc_version_string}' for dashboard comparison")
        legacy_dashboard = true
      end
    else
      legacy_dashboard = true
    end
    # Store in capabilities hash
    self.capabilities = (capabilities || {}).merge(:legacy_dashboard => legacy_dashboard)
    save! if changed?
  end

  def use_legacy_dashboard?
    # Simply read from cached capabilities
    !!capabilities["legacy_dashboard"]
  end

  def parse_hmc_version(version_string)
    # Handle IBM HMC version formats:
    # - Numeric: "10.2.1030.0" -> [10, 2, 1030, 0]
    # - IBM format: "V11R1 1110" -> [11, 1, 1110]
    # - IBM format: "V10R2 1020" -> [10, 2, 1020]
    version_string = version_string.to_s.strip
    # Validate input is not empty
    raise ArgumentError, "Invalid IBM HMC version format: empty string" if version_string.empty?

    if version_string.match?(/^V\d+R\d+/)
      # IBM format: extract numbers from "V<major>R<minor> <build>"
      # e.g., "V11R1 1110" -> "11.1.1110"
      version_parts = version_string.match(/V(?<major>\d+)R(?<minor>\d+)\s*(?<build>\d+)?/)&.named_captures
      if version_parts
        version = version_parts.values_at("major", "minor", "build")
                               .compact.map(&:to_i).join(".")
        Gem::Version.new(version)
      else
        raise ArgumentError, "Invalid IBM HMC version format: #{version_string}"
      end
    else
      # Standard numeric format: "10.2.1030.0"
      # Validate that it only contains digits and dots
      unless version_string.match?(/^\d+(\.\d+)*$/)
        raise ArgumentError, "Invalid IBM HMC version format: #{version_string}"

      end

      begin
        Gem::Version.new(version_string)
      rescue ArgumentError => e
        raise ArgumentError, "Invalid IBM HMC version format: #{e.message}"
      end
    end
  end

  def fetch_and_store_hmc_version(connection)
    return unless connection

    begin
      hmc_console = connection.management_console
      # HMC version is split across two attributes:
      # - hmc_console.version contains release (e.g., "V11R1")
      # - hmc_console.sp_name contains service pack/build (e.g., "1110")
      version_part = hmc_console.version
      sp_part = hmc_console.sp_name
      # Combine both parts to form complete version (e.g., "V11R1 1110")
      hmc_version = [version_part, sp_part].join(" ")
      if hmc_version.present?
        self.api_version = hmc_version
        save! if changed?
      end
    rescue => e
      $ibm_power_hmc_log.warn("Failed to fetch HMC version: #{e.message}")
      # Don't fail credential verification if version fetch fails
    end
  end

  def self.ems_type
    @ems_type ||= "ibm_power_hmc".freeze
  end

  def self.description
    @description ||= "IBM Power HMC".freeze
  end

  def self.catalog_types
    {"ibm_power_hmc" => N_("IBM Power HMC")}
  end
end
