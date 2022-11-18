describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Refresher do
  let(:ems)               { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }
  let(:host_uuid)         { "0685d4a6-2021-3044-84e3-59f44e9cc5d7" }
  let(:vios_uuid)         { "4165A16F-0766-40F3-B9E2-7272E1910F2E" }
  let(:lpar_uuid)         { "646AE0BC-CF06-4F6B-83CB-7A3ECCF903E3" }
  let(:template_uuid)     { "84f2d0b8-d86e-4a51-a012-8ddc4339c1f7" }
  let(:storage_uuid)      { "8f2a83e9-f4c7-35e5-987e-9ac54a498dab" }
  let(:respool_cpu_uuid)  { "d47a585d-eaa8-3a54-b4dc-93346276ea37_c41d8844-1d39-3512-944d-50f58de2d42d" }
  let(:respool_mem_uuid)  { "d47a585d-eaa8-3a54-b4dc-93346276ea37_557f7755-a4dc-30de-816d-387f42dd8fd3" }

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ibm_power_hmc)
  end

  context "#refresh" do
    it "full refresh" do
      2.times do
        full_refresh(ems)
        ems.reload
      end

      assert_ems
      assert_specific_host
      assert_specific_switch
      assert_specific_lan
      assert_specific_vios
      assert_specific_lpar
      assert_specific_template
      assert_specific_resource_pool_cpu
      assert_specific_resource_pool_mem
      assert_specific_storage
    end
  end

  context "#target_refresh" do
    before { full_refresh(ems) }

    def target_refresh(target, example)
      expect(target).not_to be_nil
      VCR.use_cassette("#{described_class.name.underscore}_#{example.description}_#{target.ems_ref}") do
        EmsRefresh.refresh(target)
      end
    end

    it "host" do |example|
      target_refresh(ems.hosts.find_by(:ems_ref => host_uuid), example)
      assert_specific_host
      assert_specific_switch
      assert_specific_lan
    end

    it "lpar" do |example|
      target_refresh(ems.vms.find_by(:ems_ref => lpar_uuid), example)
      assert_specific_lpar
    end

    it "vios" do |example|
      target_refresh(ems.vms.find_by(:ems_ref => vios_uuid), example)
      assert_specific_vios
    end

    it "template" do |example|
      target_refresh(ems.miq_templates.find_by(:ems_ref => template_uuid), example)
      assert_specific_template
    end

    it "storage" do |example|
      target_refresh(ems.storages.find_by(:ems_ref => storage_uuid), example)
      assert_specific_storage
    end

    it "resource_pool (cpu)" do |example|
      target_refresh(ems.resource_pools.find_by(:ems_ref => respool_cpu_uuid), example)
      assert_specific_resource_pool_cpu
    end

    it "resource_pool (mem)" do |example|
      target_refresh(ems.resource_pools.find_by(:ems_ref => respool_mem_uuid), example)
      assert_specific_resource_pool_mem
    end
  end

  def full_refresh(target)
    VCR.use_cassette(described_class.name.underscore) do
      EmsRefresh.refresh(target)
    end
  end

  def assert_ems
    expect(ems.last_refresh_error).to be_nil
    expect(ems.last_refresh_date).not_to be_nil

    expect(ems.vms.count).to be > 1

    expect(ems.type).to eq("ManageIQ::Providers::IbmPowerHmc::InfraManager")
  end

  def assert_specific_host
    host = ems.hosts.find_by(:ems_ref => host_uuid)
    expect(host).to have_attributes(
      :ems_ref     => host_uuid,
      :name        => "porthos",
      :ipaddress   => "10.197.64.46",
      :power_state => "on",
      :vmm_vendor  => "ibm_power_hmc"
    )
    expect(host.operating_system).to have_attributes(
      :product_name => "phyp",
      :build_number => "SV860_FW860.61 (185)"
    )
    expect(host.hardware).to have_attributes(
      :cpu_type        => "ppc64",
      :bitness         => 64,
      :model           => "828642A",
      :cpu_speed       => 4_157,
      :memory_mb       => 720_896,
      :cpu_total_cores => 16,
      :serial_number   => "103341V"
    )

    io = host.hardware.physical_ports.find_by(:location => "U78C9.001.WZS00M8-P1-C15")
    expect(io).to have_attributes(
      :device_type     => "physical_port",
      :controller_type => "IO",
      :model           => "PCIe3 x8 SAS RAID Internal Adapter 6Gb"
    )

    setting = host.advanced_settings.find_by(:name => "pcm_enabled")
    expect(setting).to have_attributes(
      :value     => "false",
      :read_only => true
    )
  end

  def assert_specific_switch
    host = ems.hosts.find_by(:ems_ref => host_uuid)
    switch = host.switches.find_by(:name => "ETHERNET0(Default)")

    expect(switch).not_to be_nil
    expect(switch.lans.count).to eq(1)
    expect(switch.hosts.count).to eq(1)
  end

  def assert_specific_lan
    host = ems.hosts.find_by(:ems_ref => host_uuid)
    switch = host.switches.find_by(:name => "ETHERNET0(Default)")
    lan = switch.lans.find_by(:name => "VLAN1-ETHERNET0")

    expect(lan).not_to be_nil
    expect(lan.switch.name).to eq("ETHERNET0(Default)")
  end

  def assert_specific_vios
    vios = ems.vms.find_by(:ems_ref => vios_uuid)
    expect(vios).to have_attributes(
      :ems_ref         => vios_uuid,
      :vendor          => "ibm_power_hmc",
      :type            => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Vios",
      :name            => "aramisios",
      :raw_power_state => "running",
      :power_state     => "on"
    )
    expect(vios.operating_system).to have_attributes(
      :product_name => "VIOS",
      :version      => "3.1.0.11"
    )
    expect(vios.hardware).to have_attributes(
      :cpu_type        => "ppc64",
      :cpu_speed       => 4_157,
      :memory_mb       => 8_192,
      :cpu_total_cores => 2
    )

    trunk = vios.hardware.nics.find_by(:address => "22:ed:8b:6e:01:02")
    expect(trunk).to have_attributes(
      :device_name     => "ent4",
      :device_type     => "ethernet",
      :controller_type => "trunk adapter"
    )
    expect(trunk.lan).not_to be_nil
    expect(trunk.lan.name).to eq("VLAN1-ETHERNET0")

    expect(vios.networks.count).to eq(1)
    network = vios.networks.first
    expect(network).to have_attributes(
      :ipaddress   => "10.197.64.55",
      :subnet_mask => "255.255.240.0"
    )

    io = vios.hardware.physical_ports.find_by(:location => "U78C9.001.WZS01L9-P1-C14")
    expect(io).to have_attributes(
      :device_type     => "physical_port",
      :controller_type => "IO",
      :model           => "PCIe3 x8 SAS RAID Internal Adapter 6Gb"
    )

    disk = vios.disks.find_by(:device_name => "hdisk0")
    expect(disk).to have_attributes(
      :controller_type => "SCSI",
      :device_type     => "disk",
      :disk_type       => "Physical Volume",
      :location        => "U78C9.001.WZS01L9-P2-D2",
      :mode            => "rw",
      :size            => 286_102.megabytes
    )

    setting = vios.advanced_settings.find_by(:name => "processor_type")
    expect(setting).to have_attributes(
      :value     => "dedicated",
      :read_only => true
    )

    setting = vios.advanced_settings.find_by(:name => "memory_type")
    expect(setting).to have_attributes(
      :value     => "dedicated",
      :read_only => true
    )

    expect(vios.labels.count).to eq(1)
    expect(vios.labels.first.name).to eq("ManageIQ")

    expect(vios.host).not_to be_nil
    expect(vios.host.name).to eq("aramis")

    # VMs with dedicated CPUs have no shared processor pool.
    expect(vios.parent_resource_pool).to be_nil
  end

  def assert_specific_lpar
    lpar = ems.vms.find_by(:ems_ref => lpar_uuid)
    expect(lpar).to have_attributes(
      :ems_ref         => lpar_uuid,
      :vendor          => "ibm_power_hmc",
      :type            => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar",
      :name            => "cooplab",
      :raw_power_state => "running",
      :power_state     => "on"
    )
    expect(lpar.operating_system).to have_attributes(
      :product_name => "AIX",
      :version      => "7.3",
      :build_number => "7300-00-00-0000"
    )
    expect(lpar.hardware).to have_attributes(
      :cpu_type        => "ppc64",
      :cpu_speed       => 4_157,
      :memory_mb       => 4_096,
      :cpu_total_cores => 1
    )

    nic = lpar.hardware.nics.find_by(:address => "be:6a:af:5d:eb:02")
    expect(nic).to have_attributes(
      :device_type     => "ethernet",
      :controller_type => "client network adapter"
    )
    expect(nic.lan).not_to be_nil
    expect(nic.lan.name).to eq("VLAN1-ETHERNET0")

    expect(lpar.networks.count).to eq(1)
    network = lpar.networks.first
    expect(network).to have_attributes(
      :ipaddress => "10.197.64.178"
    )

    expect(lpar.disks.count).to eq(1)

    disk = lpar.disks.first
    expect(disk).to have_attributes(
      :controller_type => "SCSI",
      :device_type     => "disk",
      :disk_type       => "Physical Volume",
      :location        => "U8286.42A.103341V-V16-C5",
      :mode            => "rw",
      :size            => 20.gigabytes
    )

    setting = lpar.advanced_settings.find_by(:name => "processor_type")
    expect(setting).to have_attributes(
      :value     => "uncapped",
      :read_only => true
    )

    setting = lpar.advanced_settings.find_by(:name => "memory_type")
    expect(setting).to have_attributes(
      :value     => "dedicated",
      :read_only => true
    )

    expect(lpar.labels.count).to eq(1)
    expect(lpar.labels.first.name).to eq("ManageIQ")

    expect(lpar.host).not_to be_nil
    expect(lpar.host.ems_ref).to eq(host_uuid)

    expect(lpar.parent_resource_pool).not_to be_nil
    expect(lpar.parent_resource_pool.name).to eq("DefaultPool")
  end

  def assert_specific_template
    template = ems.miq_templates.find_by(:ems_ref => template_uuid)
    expect(template).to have_attributes(
      :ems_ref  => template_uuid,
      :vendor   => "ibm_power_hmc",
      :type     => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Template",
      :name     => "miq-template-test",
      :template => true
    )

    expect(template.hardware).to have_attributes(
      :cpu_type        => "ppc64",
      :memory_mb       => 16_384,
      :cpu_total_cores => 4
    )

    setting = template.advanced_settings.find_by(:name => "processor_type")
    expect(setting).to have_attributes(
      :value     => "uncapped",
      :read_only => true
    )

    setting = template.advanced_settings.find_by(:name => "memory_type")
    expect(setting).to have_attributes(
      :value     => "dedicated",
      :read_only => true
    )
  end

  def assert_specific_resource_pool_cpu
    cpu_pool = ems.resource_pools.find_by(:ems_ref => respool_cpu_uuid)
    expect(cpu_pool).to have_attributes(
      :type => "ManageIQ::Providers::IbmPowerHmc::InfraManager::ProcessorResourcePool"
    )
  end

  def assert_specific_resource_pool_mem
    mem_pool = ems.resource_pools.find_by(:ems_ref => respool_mem_uuid)
    expect(mem_pool).to have_attributes(
      :type => "ManageIQ::Providers::IbmPowerHmc::InfraManager::MemoryResourcePool"
    )
  end

  def assert_specific_storage
    storage = ems.storages.find_by(:ems_ref => storage_uuid)
    expect(storage).to have_attributes(
      :ems_ref => storage_uuid,
      :name    => "SSP_1",
      :type    => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Storage"
    )
  end
end
