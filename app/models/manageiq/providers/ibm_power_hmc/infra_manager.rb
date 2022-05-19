class ManageIQ::Providers::IbmPowerHmc::InfraManager < ManageIQ::Providers::InfraManager
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :EventTargetParser
  require_nested :Host
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :Refresher
  require_nested :RefreshWorker
  require_nested :Template
  require_nested :Vm
  require_nested :Lpar
  require_nested :Vios
  require_nested :Storage

  supports :create
  supports :metrics
  supports :provisioning

  has_many :hosts_advanced_settings, :through => :hosts, :source => :advanced_settings

  def self.params_for_create
    @params_for_create ||= {
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
              :validationDependencies => %w[type zone_id],
              :fields                 => [
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
                  :initialValue => 12_443,
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
      connect(:validate => true)
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

    hc = IbmPowerHmc::Connection.new(:host => hostname, :port => port, :username => userid, :password => password, :validate_ssl => validate_ssl)
    if validate
      # Do a logon/logoff to verify credentials
      hc.logon
      hc.logoff
    end

    hc
  end

  def self.ems_type
    @ems_type ||= "ibm_power_hmc".freeze
  end

  def self.description
    @description ||= "IBM Power HMC".freeze
  end
end
