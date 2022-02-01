describe ManageIQ::Providers::IbmPowerHmc::InfraManager::EventTargetParser do
  class TestEventTargetParser
    attr_accessor :type, :id, :published, :data, :detail, :usertask
    def initialize(data, usertask = nil)
      @type     = "ADD_URI"
      @id       = "1639561179310"
      @data     = data
      @detail   = "Other"
      @usertask = usertask
    end
  end

  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryBot.create(:ems_ibm_power_hmc_infra, :zone => zone)
  
    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end
  
  context "ADD_URI event" do
    it "ManagedSystem" do
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/ManagedSystem/977848c8-3bed-360a-c9d2-ae4b7e46b5d1",
        [[:hosts, {:ems_ref => '977848c8-3bed-360a-c9d2-ae4b7e46b5d1'}]]
      )
    end
    it "LogicalPartition" do
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/LogicalPartition/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        [[:vms, {:ems_ref => '74CC38E2-C6DD-4B03-A0C6-088F7882EF0E'}]]
      )
    end
    it "VirtualIOServer" do
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/VirtualIOServer/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        [[:vms, {:ems_ref => '74CC38E2-C6DD-4B03-A0C6-088F7882EF0E'}]]
      )
    end
    it "VirtualSwitch" do
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/VirtualSwitch/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        [[:hosts, {:ems_ref => 'e4acf909-6d0b-3c03-b75a-4d8495e5fc49'}]]
      )
    end
    it "VirtualNetwork" do
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/VirtualNetwork/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        [[:hosts, {:ems_ref => 'e4acf909-6d0b-3c03-b75a-4d8495e5fc49'}]]
      )
    end
    it "Template" do
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/UserTask/66418e41-325d-4e7d-bb86-2f6454385fa5",
        [[:miq_templates, {:ems_ref => '63fe140d-4066-4732-93cd-bbaa0ac2822e'}]],
        {"uuid"=>"66418e41-325d-4e7d-bb86-2f6454385fa5", "key"=>"TEMPLATE_PARTITION_SAVE", "localizedLabel"=>"Save", "labelParams"=>["TEST"], "initiator"=>"hscroot", "timeStarted"=>1643114778401, "timeCompleted"=>1643114781641, "status"=>"Completed", "visible"=>true, "template_uuid"=>"63fe140d-4066-4732-93cd-bbaa0ac2822e"}
      )
    end
    it "Template delete" do
      FactoryBot.create(
        :ibm_power_hmc_template,
        :uid_ems => '12345678',
        :ems_ref => '12345678',
        :name => "supertest",
        :vendor => "ibm_power_vm",
        :template => true,
        :location => "unknown",
        :raw_power_state => "never",
        :ems_id => @ems.id)
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/UserTask/66418e41-325d-4e7d-bb86-2f6454385fa5",
        [[:miq_templates, {:ems_ref => '12345678'}]],
        {"uuid"=>"948b4654-7d09-4869-a065-7d3301588a99", "key"=>"TEMPLATE_DELETE", "localizedLabel"=>"Delete the template named supertest", "labelParams"=>["supertest"], "initiator"=>"hscroot", "timeStarted"=>1643116605280, "timeCompleted"=>1643116605327, "status"=>"Completed", "visible"=>true}
      )
    end
    it "Cluster" do
      assert_event_triggers_target(
        "https://te.st:12443/rest/api/uom/Cluster/c1e50c27-888c-3c4d-8d4a-53a3768ea250",
        [[:storages, {:ems_ref => 'c1e50c27-888c-3c4d-8d4a-53a3768ea250'}]]
      )
    end
  end

  def assert_event_triggers_target(event_data, expected_targets, usertask = nil)
    ems_event      = create_ems_event(event_data, usertask)
    parsed_targets = described_class.new(ems_event).parse

    expect(parsed_targets.size).to eq(expected_targets.count)
    expect(target_references(parsed_targets)).to(
      match_array(expected_targets)
    )
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end

  def create_ems_event(event_data, usertask = nil)
    event_hash = ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser.event_to_hash(TestEventTargetParser.new(event_data, usertask), @ems.id)
    EmsEvent.add(@ems.id, event_hash)
  end
end