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
      assert_specific_vm
    end

    def assert_ems
      expect(ems.last_refresh_error).to be_nil
      expect(ems.last_refresh_date).not_to be_nil

      expect(ems.vms.count).to be > 1

      expect(ems.type).to eq("ManageIQ::Providers::IbmPowerHmc::InfraManager")
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
    end
  end

  context "#target_refresh" do
    let(:ems) do
      ext = FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
      full_refresh(ext)
      ext
    end

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
