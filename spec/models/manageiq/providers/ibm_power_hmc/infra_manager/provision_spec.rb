describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision do
  let(:admin)    { FactoryBot.create(:user_with_group) }
  let(:ems)      { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }
  let(:host)     { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "host1_uuid", :name => "host1") }
  let(:vm)       { FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "vm1_uuid", :name => "vm1", :host => host) }
  let(:template) { FactoryBot.create(:ibm_power_hmc_template, :ext_management_system => ems, :ems_ref => "template1_uuid", :name => "template1") }

  context "provisioning" do
    let(:pr) do
      FactoryBot.create(:miq_provision_request, :requester => admin, :src_vm_id => template.id)
    end
    let(:prov) do
        FactoryBot.create(
          :ibm_power_hmc_miq_provision,
          :userid       => admin.userid,
          :miq_request  => pr,
          :source       => template,
          :request_type => 'template',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => {:src_vm_id => [template.id, template.name]}
        )
    end

    it "destination_type" do
      expect(prov.destination_type).to eq("Vm")
    end
    it "find_destination_in_vmdb" do
      expect(prov.find_destination_in_vmdb(vm.ems_ref).ems_ref).to eq(vm.ems_ref)
    end
  end

  context "publish" do
    let(:pr) do
      FactoryBot.create(:miq_provision_request, :requester => admin, :src_vm_id => vm.id)
    end
    let(:prov) do
        FactoryBot.create(
          :ibm_power_hmc_miq_provision,
          :userid       => admin.userid,
          :miq_request  => pr,
          :source       => vm,
          :request_type => 'clone_to_template',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => {:src_vm_id => [vm.id, vm.name]}
        )
    end

    it "destination_type" do
      expect(prov.destination_type).to eq("Template")
    end
    it "find_destination_in_vmdb" do
      expect(prov.find_destination_in_vmdb(template.ems_ref).ems_ref).to eq(template.ems_ref)
    end
  end

  context "clone" do
    let(:pr) do
      FactoryBot.create(:miq_provision_request, :requester => admin, :src_vm_id => template.id)
    end
    let(:prov) do
        FactoryBot.create(
          :ibm_power_hmc_miq_provision,
          :userid       => admin.userid,
          :miq_request  => pr,
          :source       => template,
          :request_type => 'clone_to_vm',
          :state        => 'pending',
          :status       => 'Ok',
          :options      => {:src_vm_id => [template.id, template.name]}
        )
    end

    it "destination_type" do
      expect(prov.destination_type).to eq("Template")
    end
    it "find_destination_in_vmdb" do
      expect(prov.find_destination_in_vmdb(template.ems_ref).ems_ref).to eq(template.ems_ref)
    end
  end
end
