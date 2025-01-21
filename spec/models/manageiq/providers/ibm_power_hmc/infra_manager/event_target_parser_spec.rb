describe ManageIQ::Providers::IbmPowerHmc::InfraManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryBot.create(:ems_ibm_power_hmc_infra, :zone => zone)
    User.seed
  end

  context "ADD_URI event" do
    it "ManagedSystem" do
      assert_event_triggers_target(
        "test_data/managed_system.xml",
        [[:hosts, {:ems_ref => '977848c8-3bed-360a-c9d2-ae4b7e46b5d1'}]]
      )
    end
    context "LogicalPartition" do
      it "targets the logical partition" do
        assert_event_triggers_target(
          "test_data/logical_partition_long_url.xml",
          [[:vms, {:ems_ref => '74CC38E2-C6DD-4B03-A0C6-088F7882EF0E'}]]
        )
      end

      context "with a missing LPAR UUID" do
        it "targets the whole EMS" do
          ems_event      = create_ems_event("test_data/logical_partition_invalid_uuid.xml")
          parsed_targets = described_class.new(ems_event).parse

          expect(parsed_targets).to eq([@ems])
        end
      end

      context "with a missing LPAR UUID and LogicalPartitionProfile included in path" do
        it "targets the whole EMS" do
          ems_event      = create_ems_event("test_data/logical_partition_profile_invalid_uuid.xml")
          parsed_targets = described_class.new(ems_event).parse

          expect(parsed_targets).to eq([@ems])
        end
      end

      context "with an invalid EventData url" do
        it "returns an empty target set" do
          ems_event      = create_ems_event("test_data/logical_partition_invalid_event_data.xml")
          parsed_targets = described_class.new(ems_event).parse

          expect(parsed_targets).to be_empty
        end
      end
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
        :vendor          => "ibm_power_hmc",
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
    it "PcmPreferences" do
      aramis = FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => @ems, :ems_ref => "aaaaaaaa-eaa8-3a54-b4dc-93346276ea37", :name => "aramis")
      porthos = FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => @ems, :ems_ref => "bbbbbbbb-eaa8-3a54-b4dc-93346276ea37", :name => "porthos")
      assert_event_triggers_target(
        "test_data/pcm_preferences.xml",
        [
          [:hosts, {:ems_ref => aramis.ems_ref}],
          [:hosts, {:ems_ref => porthos.ems_ref}]
        ],
        {
          "uuid"           => "99630d72-36b7-4fa6-8307-b70aef13b0b0",
          "key"            => "PCM_PREFERENCE_UPDATE",
          "localizedLabel" => "Update performance monitoring settings",
          "labelParams"    => ["[aramis, porthos]"],
          "initiator"      => "hscroot",
          "timeStarted"    => 1_652_866_657_499,
          "timeCompleted"  => 1_652_866_657_594,
          "status"         => "Completed",
          "visible"        => true
        }
      )
    end
    it "SharedProcessorPool" do
      assert_event_triggers_target(
        "test_data/shared_processor_pool.xml",
        [[:resource_pools, {:ems_ref => 'd47a585d-eaa8-3a54-b4dc-93346276ea37_27aae064-2855-39a0-b4e6-e3c9b5572036'}]]
      )
    end
    it "SharedMemoryPool" do
      assert_event_triggers_target(
        "test_data/shared_memory_pool.xml",
        [[:resource_pools, {:ems_ref => 'd47a585d-eaa8-3a54-b4dc-93346276ea37_557f7755-a4dc-30de-816d-387f42dd8fd3'}]]
      )
    end
  end

  context "Ignored Usertasks" do
    it "Ignored key" do
      assert_event_triggers_target(
        "test_data/ignored_usertask.xml",
        nil,
        {
          "uuid"           => "58ad2817-3365-4de4-a9fe-f0a587bfc326",
          "key"            => "CCFW_POOL_MANAGEMENT_TASK",
          "localizedLabel" => "Shared memory pool",
          "labelParams"    => ["system 2022/11/07 08:44:10.022", "id 62"],
          "initiator"      => "hscroot",
          "timeStarted"    => 1_668_072_627_838,
          "timeCompleted"  => 1_668_072_632_703,
          "status"         => "Completed",
          "visible"        => true
        }
      )
    end
    it "Running UserTask" do
      assert_event_triggers_target(
        "test_data/pcm_preferences.xml",
        nil,
        {
          "uuid"           => "99630d72-36b7-4fa6-8307-b70aef13b0b0",
          "key"            => "PCM_PREFERENCE_UPDATE",
          "localizedLabel" => "Update performance monitoring settings",
          "labelParams"    => ["[aramis, porthos]"],
          "initiator"      => "hscroot",
          "timeStarted"    => 1_652_866_657_499,
          "timeCompleted"  => 1_652_866_657_594,
          "status"         => "Running",
          "visible"        => true
        }
      )
    end
  end

  def assert_event_triggers_target(filename, expected_targets, usertask = nil)
    ems_event      = create_ems_event(filename, usertask)
    parsed_targets = described_class.new(ems_event).parse

    aggregate_failures "expected_targets" do
      expect(parsed_targets.size).to eq(expected_targets.count) unless expected_targets.nil?
      expect(target_references(parsed_targets)).to(
        match_array(expected_targets)
      )
    end
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end

  def create_ems_event(filename, usertask = nil)
    require "ibm_power_hmc"
    event = IbmPowerHmc::FeedParser.new(File.read(File.join(File.dirname(__FILE__), filename))).objects(:Event).first
    event.usertask = usertask
    event_hash = ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser.event_to_hash(event, @ems.id)
    EmsEvent.add(@ems.id, event_hash)
  end
end
