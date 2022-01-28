describe ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser do
  class TestEvent
    attr_accessor :type, :id, :published, :data, :detail, :usertask
    def initialize
      @type   = "ADD_URI"
      @id     = "1639561179310"
      @data   = "https://te.st:12443/rest/api/uom/ManagedSystem/977848c8-3bed-360a-c9d2-ae4b7e46b5d1"
      @detail = "Other"
    end
  end

  context "ManagedSystem" do
    it "#event_to_hash" do
      ems_id = "999"
      event = TestEvent.new
      expect(described_class.event_to_hash(event, ems_id)).to(
        include(
          :source       => 'IBM_POWER_HMC',
          :event_type   => "ADD_URI",
          :ems_ref      => "1639561179310",
          :timestamp    => nil,
          :ems_id       => ems_id,
          :full_data    => {
            :data     => "https://te.st:12443/rest/api/uom/ManagedSystem/977848c8-3bed-360a-c9d2-ae4b7e46b5d1",
            :detail   => "Other",
            :usertask => nil },
          :host_ems_ref => "977848c8-3bed-360a-c9d2-ae4b7e46b5d1"
        )
      )
    end
  end

  context "LogicalPartition" do
    it "#event_to_hash" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/LogicalPartition/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49"
        )
      )
    end
  end

  context "LogicalPartition" do
    it "#event_to_hash2" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/LogicalPartition/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        )
      )
    end
  end

  context "VirtualIOServer" do
    it "#event_to_hash" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/VirtualIOServer/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49"
        )
      )
    end
  end

  context "VirtualIOServer" do
    it "#event_to_hash2" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/VirtualIOServer/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        )
      )
    end
  end

  context "VirtualSwitch" do
    it "#event_to_hash" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/VirtualSwitch/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vswitch_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49"
        )
      )
    end
  end

  context "VirtualSwitch" do
    it "#event_to_hash2" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/VirtualSwitch/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vswitch_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        )
      )
    end
  end

  context "VirtualNetwork" do
    it "#event_to_hash" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/ManagedSystem/e4acf909-6d0b-3c03-b75a-4d8495e5fc49/VirtualNetwork/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vlan_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49"
        )
      )
    end
  end

  context "VirtualNetwork" do
    it "#event_to_hash2" do
      event = TestEvent.new
      event.data = "https://te.st:12443/rest/api/uom/VirtualNetwork/74CC38E2-C6DD-4B03-A0C6-088F7882EF0E"
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vlan_ems_ref  => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
        )
      )
    end
  end
end