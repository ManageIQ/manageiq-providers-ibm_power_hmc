describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Refresher do
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
      lpar_id = "646AE0BC-CF06-4F6B-83CB-7A3ECCF903E3"
      vm = ems.vms.find_by(:ems_ref => lpar_id)
      expect(vm).to have_attributes(
        :ems_ref         => lpar_id,
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

    def full_refresh(ems)
      VCR.use_cassette(described_class.name.underscore) do
        EmsRefresh.refresh(ems)
      end
    end
  end
end
