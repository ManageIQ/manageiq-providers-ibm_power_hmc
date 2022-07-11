describe ManageIQ::Providers::IbmPowerHmc::InfraManager::ProvisionWorkflow do
  include Spec::Support::WorkflowHelper

  let(:admin)    { FactoryBot.create(:user_with_group) }
  let(:template) { FactoryBot.create(:ibm_power_hmc_template, :ext_management_system => ems) }
  let(:ems)      { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }
  let(:workflow) { described_class.new({:src_vm_id => template.id}, admin.userid) }
  let(:switch1)  { FactoryBot.create(:switch, :name => "A") }
  let(:switch2)  { FactoryBot.create(:switch, :name => "B") }
  let!(:host1)   { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "HOST1", :switches => [switch1]) }
  let!(:host2)   { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "HOST2", :switches => [switch2]) }
  let!(:vlan1)   { FactoryBot.create(:lan, :name => "lan_A", :switch_id => switch1.id, :ems_ref => host1.ems_ref) }
  let!(:vlan2)   { FactoryBot.create(:lan, :name => "lan_B", :switch_id => switch2.id, :ems_ref => host2.ems_ref) }

  before do
    stub_dialog(:get_dialogs)
  end

  context '#allowed_hosts' do
    it 'finds all hosts with allowed_hosts and no selected network' do
      expect(workflow.allowed_hosts).to match_array([host1, host2].map { |h| workflow.host_to_hash_struct(h) })
    end

    it 'finds all hosts with no selected network' do
      expect(workflow.allowed_hosts_obj).to match_array([host1, host2])
    end
  end

  context "#allowed_vlans" do
    it 'finds all vlans with no selected host' do
      expect(workflow.allowed_vlans).to match_array([[vlan1.name, vlan1.name], [vlan2.name, vlan2.name]])
    end

    it 'finds all vlans with a selected host' do
      allow(workflow).to receive(:allowed_hosts).with(no_args).and_return([workflow.host_to_hash_struct(host1)])
      expect(workflow.allowed_vlans).to match_array([[vlan1.name, vlan1.name]])
    end
  end
end
