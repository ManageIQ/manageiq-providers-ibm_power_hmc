describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Refresher do
  let(:host_uuid)     { "0685d4a6-2021-3044-84e3-59f44e9cc5d7" }
  let(:vios_uuid)     { "4165A16F-0766-40F3-B9E2-7272E1910F2E" }
  let(:lpar_uuid)     { "646AE0BC-CF06-4F6B-83CB-7A3ECCF903E3" }
  let(:template_uuid) { "3f109ae5-8553-4545-b211-c0de284c4872" }
  let(:storage_uuid)  { "8f2a83e9-f4c7-35e5-987e-9ac54a498dab" }

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ibm_power_hmc)
  end

  context "#refresh" do
    let(:ems) do
      FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
    end

    it "full refresh" do
      2.times do
        full_refresh(ems)
        ems.reload
      end

      assert_ems
      assert_specific_host
      assert_specific_switch
      assert_specific_lan
      assert_specific_vm
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

    def assert_specific_vm
      vm = ems.vms.find_by(:ems_ref => lpar_uuid)
      expect(vm).to have_attributes(
        :ems_ref         => lpar_uuid,
        :vendor          => "ibm_power_hmc",
        :type            => "ManageIQ::Providers::IbmPowerHmc::InfraManager::Lpar",
        :name            => "cooplab",
        :raw_power_state => "running",
        :power_state     => "on"
      )
      expect(vm.operating_system).to have_attributes(
        :product_name => "AIX",
        :version      => "7.3",
        :build_number => "7300-00-00-0000"
      )
      expect(vm.hardware).to have_attributes(
        :cpu_type        => "ppc64",
        :cpu_speed       => 4_157,
        :memory_mb       => 4_096,
        :cpu_total_cores => 1
      )

      nic = vm.hardware.guest_devices.find_by(:address => "be:6a:af:5d:eb:02")
      expect(nic).to have_attributes(
        :device_type     => "ethernet",
        :controller_type => "client network adapter"
      )
      expect(nic.lan).not_to be_nil
      expect(nic.lan.name).to eq("VLAN1-ETHERNET0")
    end
  end

  context "#target_refresh" do
    let(:ems) { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }

    before { full_refresh(ems) }

    def target_refresh(target, example)
      expect(target).not_to be_nil
      VCR.use_cassette("#{described_class.name.underscore}_#{example.description}_#{target.ems_ref}") do
        EmsRefresh.refresh(target)
      end
    end

    it "host" do |example|
      target_refresh(ems.hosts.find_by(:ems_ref => host_uuid), example)
    end

    it "lpar" do |example|
      target_refresh(ems.vms.find_by(:ems_ref => lpar_uuid), example)
    end

    it "vios" do |example|
      target_refresh(ems.vms.find_by(:ems_ref => vios_uuid), example)
    end

    it "template" do |example|
      target_refresh(ems.miq_templates.find_by(:ems_ref => template_uuid), example)
    end

    it "storage" do |example|
      target_refresh(ems.storages.find_by(:ems_ref => storage_uuid), example)
    end
  end

  def full_refresh(target)
    VCR.use_cassette(described_class.name.underscore) do
      EmsRefresh.refresh(target)
    end
  end
end
