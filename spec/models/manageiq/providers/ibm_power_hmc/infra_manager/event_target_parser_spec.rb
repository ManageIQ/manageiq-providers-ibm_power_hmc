describe ManageIQ::Providers::IbmPowerHmc::InfraManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryBot.create(:ems_ibm_power_hmc_infra, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "ADD_URI event" do
    it "ManagedSystem" do
      assert_event_triggers_target(
        "test_data/managed_system.xml",
        [[:hosts, {:ems_ref => '977848c8-3bed-360a-c9d2-ae4b7e46b5d1'}]]
      )
    end
    it "LogicalPartition" do
      assert_event_triggers_target(
        "test_data/logical_partition_long_url.xml",
        [[:vms, {:ems_ref => '74CC38E2-C6DD-4B03-A0C6-088F7882EF0E'}]]
      )
    end
    it "VirtualIOServer" do
      assert_event_triggers_target(
        "test_data/virtual_io_server_long_url.xml",
        [[:vms, {:ems_ref => '74CC38E2-C6DD-4B03-A0C6-088F7882EF0E'}]]
      )
    end
    it "VirtualSwitch" do
      assert_event_triggers_target(
        "test_data/virtual_switch_long_url.xml",
        [[:hosts, {:ems_ref => 'e4acf909-6d0b-3c03-b75a-4d8495e5fc49'}]]
      )
    end
    it "VirtualNetwork" do
      assert_event_triggers_target(
        "test_data/virtual_network_long_url.xml",
        [[:hosts, {:ems_ref => 'e4acf909-6d0b-3c03-b75a-4d8495e5fc49'}]]
      )
    end
    it "Template" do
      assert_event_triggers_target(
        "test_data/template.xml",
        [[:miq_templates, {:ems_ref => '63fe140d-4066-4732-93cd-bbaa0ac2822e'}]],
        {
          "uuid"           => "1d43a4a6-903c-46f8-865d-a356559bb17f",
          "key"            => "TEMPLATE_PARTITION_SAVE",
          "localizedLabel" => "Save",
          "labelParams"    => ["TEST"],
          "initiator"      => "hscroot",
          "timeStarted"    => 1_643_891_701_901,
          "timeCompleted"  => 1_643_891_702_051,
          "status"         => "Completed",
          "visible"        => true,
          "template_uuid"  => "63fe140d-4066-4732-93cd-bbaa0ac2822e"
        }
      )
    end
    it "Template delete" do
      FactoryBot.create(
        :ibm_power_hmc_template,
        :uid_ems         => '12345678',
        :ems_ref         => '12345678',
        :name            => "supertest",
        :vendor          => "ibm_power_vm",
        :template        => true,
        :location        => "unknown",
        :raw_power_state => "never",
        :ems_id          => @ems.id
      )
      assert_event_triggers_target(
        "test_data/template.xml",
        [[:miq_templates, {:ems_ref => '12345678'}]],
        {
          "uuid"           => "1d43a4a6-903c-46f8-865d-a356559bb17f",
          "key"            => "TEMPLATE_DELETE",
          "localizedLabel" => "Delete the template named supertest",
          "labelParams"    => ["supertest"],
          "initiator"      => "hscroot",
          "timeStarted"    => 1_643_891_701_901,
          "timeCompleted"  => 1_643_891_702_051,
          "status"         => "Completed",
          "visible"        => true
        }
      )
    end
    it "Cluster" do
      assert_event_triggers_target(
        "test_data/cluster.xml",
        [[:storages, {:ems_ref => 'c1e50c27-888c-3c4d-8d4a-53a3768ea250'}]]
      )
    end
  end

  def assert_event_triggers_target(filename, expected_targets, usertask = nil)
    ems_event      = create_ems_event(filename, usertask)
    parsed_targets = described_class.new(ems_event).parse

    expect(parsed_targets.size).to eq(expected_targets.count)
    expect(target_references(parsed_targets)).to(
      match_array(expected_targets)
    )
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end

  def create_ems_event(filename, usertask = nil)
    event = IbmPowerHmc::FeedParser.new(File.read(File.join(File.dirname(__FILE__), filename))).objects(:Event).first
    event.usertask = usertask
    event_hash = ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser.event_to_hash(event, @ems.id)
    EmsEvent.add(@ems.id, event_hash)
  end
end
