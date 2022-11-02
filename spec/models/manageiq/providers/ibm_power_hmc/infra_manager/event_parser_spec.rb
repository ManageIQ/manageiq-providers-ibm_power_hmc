describe ManageIQ::Providers::IbmPowerHmc::InfraManager::EventParser do
  let(:event) do
    require "ibm_power_hmc"
    IbmPowerHmc::FeedParser.new(File.read(File.join(File.dirname(__FILE__), filename))).objects(:Event).first
  end

  context "ManagedSystem" do
    let(:filename) { "test_data/managed_system.xml" }
    it "#event_to_hash" do
      ems_id = "999"
      expect(described_class.event_to_hash(event, ems_id)).to(
        include(
          :source       => 'IBM_POWER_HMC',
          :event_type   => "ADD_URI",
          :ems_ref      => "1639561179310",
          :timestamp    => Time.xmlschema("2022-02-02T15:05:12.772Z"),
          :ems_id       => ems_id,
          :full_data    => {
            :data     => "https://te.st:12443/rest/api/uom/ManagedSystem/977848c8-3bed-360a-c9d2-ae4b7e46b5d1",
            :detail   => "Other",
            :usertask => nil
          },
          :host_ems_ref => "977848c8-3bed-360a-c9d2-ae4b7e46b5d1"
        )
      )
    end
  end

  context "LogicalPartition" do
    let(:filename) { "test_data/logical_partition_long_url.xml" }
    it "#event_to_hash" do
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref   => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49",
          :message      => "Other"
        )
      )
    end
  end

  context "LogicalPartition" do
    let(:filename) { "test_data/logical_partition_short_url.xml" }
    it "#event_to_hash2" do
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :message    => "Other"
        )
      )
    end
  end

  context "VirtualIOServer" do
    let(:filename) { "test_data/virtual_io_server_long_url.xml" }
    it "#event_to_hash" do
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref   => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49",
          :message      => "Other"
        )
      )
    end
  end

  context "VirtualIOServer" do
    let(:filename) { "test_data/virtual_io_server_short_url.xml" }
    it "#event_to_hash2" do
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :vm_ems_ref => "74CC38E2-C6DD-4B03-A0C6-088F7882EF0E",
          :message    => "Other"
        )
      )
    end
  end

  context "VirtualSwitch" do
    let(:filename) { "test_data/virtual_switch_long_url.xml" }
    it "#event_to_hash" do
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49",
          :message      => "Other"
        )
      )
    end
  end

  context "VirtualSwitch" do
    let(:filename) { "test_data/virtual_switch_short_url.xml" }
    it "#event_to_hash2" do
      expect(described_class.event_to_hash(event, nil)).not_to have_key(:host_ems_ref)
    end
  end

  context "VirtualNetwork" do
    let(:filename) { "test_data/virtual_network_long_url.xml" }
    it "#event_to_hash" do
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :host_ems_ref => "e4acf909-6d0b-3c03-b75a-4d8495e5fc49",
          :message      => "Other"
        )
      )
    end
  end

  context "VirtualNetwork" do
    let(:filename) { "test_data/virtual_network_short_url.xml" }
    it "#event_to_hash2" do
      expect(described_class.event_to_hash(event, nil)).not_to have_key(:host_ems_ref)
    end
  end

  context "SharedProcessorPool" do
    let(:filename) { "test_data/shared_processor_pool.xml" }
    it "#event_to_hash" do
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :host_ems_ref => "d47a585d-eaa8-3a54-b4dc-93346276ea37",
          :message      => "PoolName"
        )
      )
    end
  end

  context "UserTask" do
    let(:filename) { "test_data/template.xml" }
    it "#event_to_hash" do
      event.usertask = {"key" => "msgtest"}
      expect(described_class.event_to_hash(event, nil)).to(
        include(
          :message      => "msgtest"
        )
      )
    end
  end
end
