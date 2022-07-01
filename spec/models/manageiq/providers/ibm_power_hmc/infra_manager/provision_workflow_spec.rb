describe ManageIQ::Providers::IbmPowerHmc::InfraManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin)    { FactoryBot.create(:user_with_group) }
  let(:template) { FactoryBot.create(:ibm_power_hmc_template) }
  let(:ems)      { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }
  let(:host)     { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "d47a585d-eaa8-3a54-b4dc-93346276ea37") }

  context '#allowed_hosts_obj' do
    let(:workflow) { described_class.new({}, admin.userid) }
    before do
      EvmSpecHelper.local_miq_server

      @host1  = FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "12345", :power_state => "on")
      @host2  = FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "67890", :power_state => "on")
      @src_vm = FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "3F3D399B-DFF3-4977-8881-C194AA47CD3A", :host => host)
      stub_dialog(:get_dialogs)
      workflow.instance_variable_set(:@values, :vm_tags => [], :src_vm_id => @src_vm.id)
      workflow.instance_variable_set(:@target_resource, nil)

      allow(workflow).to receive(:find_all_ems_of_type).and_return([@host1, @host2])
      allow(Rbac).to receive(:search) do |hash|
        [Array.wrap(hash[:targets])]
      end
    end

    it 'finds all hosts with no selected network' do
      workflow.instance_variable_set(:@values, :src_vm_id => @src_vm.id)
      expect(workflow.allowed_hosts_obj).to match_array([@host1, @host2])
    end
  end

  context '#allowed_hosts_obj_no_stubs' do
    let(:workflow) { described_class.new({}, admin.userid) }

    before do
      stub_dialog(:get_dialogs)
      workflow.instance_variable_set(:@values, :src_vm_id => template.id)
    end

    it 'finds all hosts with no selected network' do
      expect(workflow.allowed_hosts_obj).to match_array([host])
    end

    it "find_all_ems_of_type" do
      expect(workflow.find_all_ems_of_type(Host)).to match_array([host])
    end
  end
end
