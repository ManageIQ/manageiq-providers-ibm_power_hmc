describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Refresher do
  let(:ems) do
    FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:ibm_power_hmc)
  end

  def full_refresh(ems)
    VCR.use_cassette(described_class.name.underscore) do
      EmsRefresh.refresh(ems)
    end
  end

  context "#refresh" do
    it "full refresh" do
      2.times do
        full_refresh(ems)
        ems.reload
      end
    end
  end

  context "#targeted_refresh" do
    let(:host)  { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "HOST") }
    let(:vios1) { FactoryBot.create(:ibm_power_hmc_vios, :ext_management_system => ems, :ems_ref => "VIOS1", :host => host) }
    let(:vios2) { FactoryBot.create(:ibm_power_hmc_vios, :ext_management_system => ems, :ems_ref => "VIOS2", :host => host) }
    let(:lpar1) { FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "LPAR1", :host => host) }
    let(:lpar2) { FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "LPAR2", :host => host) }
    let(:lpar3) { FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "LPAR3", :host => host) }
    let(:hardware1) { FactoryBot.create(:hardware, :vm => vios1) }
    let(:hardware2) { FactoryBot.create(:hardware, :vm => vios2) }
    let!(:guest_device1f) { FactoryBot.create(:ibm_power_hmc_guest_device_vfc,  :hardware => hardware1, :ems_ref => lpar1.ems_ref) }
    let!(:guest_device2f) { FactoryBot.create(:ibm_power_hmc_guest_device_vfc,  :hardware => hardware2, :ems_ref => lpar2.ems_ref) }
    let!(:guest_device3f) { FactoryBot.create(:ibm_power_hmc_guest_device_vfc,  :hardware => hardware1, :ems_ref => lpar3.ems_ref) }
    let!(:guest_device4f) { FactoryBot.create(:ibm_power_hmc_guest_device_vfc,  :hardware => hardware2, :ems_ref => lpar3.ems_ref) }
    let(:guest_device1s) { FactoryBot.create(:ibm_power_hmc_guest_device_vscsi, :hardware => hardware1, :ems_ref => lpar1.ems_ref) }
    let(:guest_device2s) { FactoryBot.create(:ibm_power_hmc_guest_device_vscsi, :hardware => hardware2, :ems_ref => lpar2.ems_ref) }
    let(:guest_device3s) { FactoryBot.create(:ibm_power_hmc_guest_device_vscsi, :hardware => hardware1, :ems_ref => lpar3.ems_ref) }
    let(:guest_device4s) { FactoryBot.create(:ibm_power_hmc_guest_device_vscsi, :hardware => hardware2, :ems_ref => lpar3.ems_ref) }
    let(:miq_scsci_target10) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device1s, :iscsi_name => "TARGET10", :uid_ems => "10") }
    let(:miq_scsci_target11) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device1s, :iscsi_name => "TARGET11", :uid_ems => "11") }
    let(:miq_scsci_target20) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device2s, :iscsi_name => "TARGET20", :uid_ems => "20") }
    let(:miq_scsci_target21) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device2s, :iscsi_name => "TARGET21", :uid_ems => "21") }
    let(:miq_scsci_target30) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device3s, :iscsi_name => "TARGET30", :uid_ems => "30") }
    let(:miq_scsci_target31) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device3s, :iscsi_name => "TARGET31", :uid_ems => "31") }
    let(:miq_scsci_target40) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device4s, :iscsi_name => "TARGET40", :uid_ems => "40") }
    let(:miq_scsci_target41) { FactoryBot.create(:miq_scsi_target, :guest_device => guest_device4s, :iscsi_name => "TARGET41", :uid_ems => "41") }
    let!(:miq_scsci_lun10) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target10, :device_name => "disk10", :uid_ems => "10") }
    let!(:miq_scsci_lun11) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target11, :device_name => "disk11", :uid_ems => "11") }
    let!(:miq_scsci_lun20) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target20, :device_name => "disk20", :uid_ems => "20") }
    let!(:miq_scsci_lun21) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target21, :device_name => "disk21", :uid_ems => "21") }
    let!(:miq_scsci_lun30) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target30, :device_name => "disk30", :uid_ems => "30") }
    let!(:miq_scsci_lun31) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target31, :device_name => "disk31", :uid_ems => "31") }
    let!(:miq_scsci_lun40) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target40, :device_name => "disk40", :uid_ems => "40") }
    let!(:miq_scsci_lun41) { FactoryBot.create(:miq_scsi_lun, :miq_scsi_target => miq_scsci_target41, :device_name => "disk41", :uid_ems => "41") }
    let(:parser) { create_parser(create_target_collection({:ems_ref => vios2.ems_ref})) }

    def create_target_collection(manager_ref)
      InventoryRefresh::TargetCollection.new(
        :targets => [InventoryRefresh::Target.new(:manager => ems, :association => :vms, :manager_ref => manager_ref)],
        :manager => ems
      )
    end

    def create_parser(target_collection)
      ManageIQ::Providers::IbmPowerHmc::Inventory::Parser::TargetCollection.new.tap do |parser|
        parser.collector = ManageIQ::Providers::IbmPowerHmc::Inventory::Collector::TargetCollection.new(ems, target_collection)
        parser.persister = ManageIQ::Providers::IbmPowerHmc::Inventory::Persister::TargetCollection.new(ems, target_collection)
      end
    end

    def rebuild_hardware(hardware)
      parser.persister.hardwares.build(
        :vm_or_template => parser.persister.vms.build(
          :type            => hardware.vm.type,
          :uid_ems         => hardware.vm.ems_ref,
          :ems_ref         => hardware.vm.ems_ref,
          :name            => hardware.vm.name,
          :location        => hardware.vm.location,
          :vendor          => hardware.vm.vendor,
          :description     => hardware.vm.description,
          :raw_power_state => hardware.vm.raw_power_state,
          :host            => hardware.vm.host.id
        )
      )
    end

    def rebuild_existing_mappings(hardware, vios)
      vios.hardware.guest_devices.each do |g|
        inv_gd = parser.persister.guest_devices.build(
          :hardware        => hardware,
          :uid_ems         => g.uid_ems,
          :ems_ref         => g.ems_ref,
          :device_type     => g.device_type,
          :controller_type => g.controller_type,
          :auto_detect     => g.auto_detect,
          :address         => g.address,
          :location        => g.location,
          :filename        => g.filename,
          :model           => g.model
        )
        g.miq_scsi_targets.each do |t|
          inv_t = parser.persister.miq_scsi_targets.build(
            :guest_device => inv_gd,
            :iscsi_name   => t.iscsi_name,
            :uid_ems      => t.uid_ems
          )
          t.miq_scsi_luns.each do |l|
            parser.persister.miq_scsi_luns.build(
              :miq_scsi_target => inv_t,
              :canonical_name  => l.canonical_name,
              :device_name     => l.device_name,
              :device_type     => l.device_type,
              :capacity        => l.capacity,
              :uid_ems         => l.uid_ems
            )
          end
        end
      end
    end

    it "creates a vfc mapping" do
      h = rebuild_hardware(hardware2)
      rebuild_existing_mappings(h, vios2)
      # Add new mapping
      parser.persister.guest_devices.build(
        :hardware        => h,
        :uid_ems         => "test",
        :ems_ref         => lpar1.ems_ref,
        :device_type     => "storage",
        :controller_type => "server vfc storage adapter",
        :auto_detect     => true,
        :address         => "",
        :location        => "",
        :filename        => "",
        :model           => ""
      )
      expect(vios2.hardware.guest_devices.size).to eq(4)
      parser.persister.persist!
      vios2.reload
      expect(vios2.hardware.guest_devices.size).to eq(5)
    end

    it "deletes a vfc mapping" do
      h = rebuild_hardware(hardware2)
      # Add all but one mappings
      vios2.hardware.guest_devices.reject { |g| g.controller_type == "server vfc storage adapter" }.each do |g|
        parser.persister.guest_devices.build(
          :hardware        => h,
          :uid_ems         => g.uid_ems,
          :ems_ref         => g.ems_ref,
          :device_type     => g.device_type,
          :controller_type => g.controller_type,
          :auto_detect     => g.auto_detect,
          :address         => g.address,
          :location        => g.location,
          :filename        => g.filename,
          :model           => g.model
        )
      end
      expect(vios2.hardware.guest_devices.size).to eq(4)
      parser.persister.persist!
      vios2.reload
      expect(vios2.hardware.guest_devices.size).to eq(2)
    end

    it "modifies vfc mappings" do
      h = rebuild_hardware(hardware2)
      # Add modified existing mappings
      vios2.hardware.guest_devices.each do |g|
        parser.persister.guest_devices.build(
          :hardware        => h,
          :uid_ems         => g.uid_ems,
          :ems_ref         => g.ems_ref,
          :device_type     => g.device_type,
          :controller_type => g.controller_type,
          :auto_detect     => g.auto_detect,
          :address         => g.address,
          :location        => g.location,
          :filename        => g.filename,
          :model           => "modified"
        )
      end
      old_id = guest_device2f.id
      expect(vios2.hardware.guest_devices.size).to eq(4)
      parser.persister.persist!
      vios2.reload
      guest_device2f.reload
      aggregate_failures "after" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2f.model).to eq("modified")
        expect(guest_device2f.id).to eq(old_id)
      end
    end

    it "creates a vscsi mapping without scsi targets" do
      h = rebuild_hardware(hardware2)
      rebuild_existing_mappings(h, vios2)
      # Add new mapping
      parser.persister.guest_devices.build(
        :hardware        => h,
        :uid_ems         => "test",
        :ems_ref         => lpar1.ems_ref,
        :device_type     => "storage",
        :controller_type => "server vfc storage adapter",
        :auto_detect     => true,
        :location        => "",
        :filename        => ""
      )
      aggregate_failures "before" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
        expect(guest_device2s.miq_scsi_targets.first.miq_scsi_luns.size).to eq(1)
      end
      parser.persister.persist!
      vios2.reload
      guest_device2s.reload
      aggregate_failures "after" do
        expect(vios2.hardware.guest_devices.size).to eq(5)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
      end
    end

    it "creates a vscsi mapping with scsi targets" do
      h = rebuild_hardware(hardware2)
      rebuild_existing_mappings(h, vios2)
      # Add new mapping
      parser.persister.miq_scsi_luns.build(
        :miq_scsi_target => parser.persister.miq_scsi_targets.build(
          :guest_device => parser.persister.guest_devices.build(
            :hardware        => h,
            :uid_ems         => "test",
            :ems_ref         => lpar1.ems_ref,
            :device_type     => "storage",
            :controller_type => "server vfc storage adapter",
            :auto_detect     => true,
            :location        => "",
            :filename        => ""
          ),
          :iscsi_name   => "new_target",
          :uid_ems      => "new_target"
        ),
        :canonical_name  => "new_lun",
        :device_name     => "new_lun",
        :device_type     => "new_lun",
        :capacity        => 1,
        :uid_ems         => "new_lun"
      )
      aggregate_failures "before" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
      end
      parser.persister.persist!
      vios2.reload
      ems.reload
      guest_device2s.reload
      new_gd = ems.guest_devices.find_by(:uid_ems => "test")
      aggregate_failures "after" do
        expect(vios2.hardware.guest_devices.size).to eq(5)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
        expect(new_gd.miq_scsi_targets.size).to eq(1)
        expect(new_gd.miq_scsi_targets.first.miq_scsi_luns.size).to eq(1)
        expect(new_gd.miq_scsi_targets.first.iscsi_name).to eq("new_target")
        expect(new_gd.miq_scsi_targets.first.miq_scsi_luns.first.device_name).to eq("new_lun")
      end
    end

    it "deletes a vscsi mapping" do
      h = rebuild_hardware(hardware2)
      # Add all but one mappings
      vios2.hardware.guest_devices.reject { |g| g.controller_type == "server vscsi storage adapter" }.each do |g|
        parser.persister.guest_devices.build(
          :hardware        => h,
          :uid_ems         => g.uid_ems,
          :ems_ref         => g.ems_ref,
          :device_type     => g.device_type,
          :controller_type => g.controller_type,
          :auto_detect     => g.auto_detect,
          :address         => g.address,
          :location        => g.location,
          :filename        => g.filename,
          :model           => g.model
        )
      end
      expect(vios2.hardware.guest_devices.size).to eq(4)
      parser.persister.persist!
      vios2.reload
      aggregate_failures "after" do
        expect(vios2.hardware.guest_devices.size).to eq(2)
        expect { guest_device2s.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { guest_device4s.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_target20.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_target21.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_target40.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_target41.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_lun20.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_lun21.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_lun40.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_lun41.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it "creates a scsi target/lun" do
      h = rebuild_hardware(hardware2)
      rebuild_existing_mappings(h, vios2)
      # Add new scsi target/lun in existing mapping
      parser.persister.miq_scsi_luns.build(
        :miq_scsi_target => parser.persister.miq_scsi_targets.build(
          :guest_device => parser.persister.guest_devices.lazy_find({:uid_ems => guest_device2s.uid_ems, :hardware => h}),
          :iscsi_name   => "new_target",
          :uid_ems      => "new_target"
        ),
        :canonical_name  => "new_lun",
        :device_name     => "new_lun",
        :device_type     => "new_lun",
        :capacity        => 1,
        :uid_ems         => "new_lun"
      )
      aggregate_failures "before" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
      end
      parser.persister.persist!
      vios2.reload
      ems.reload
      guest_device2s.reload
      new_target = ems.miq_scsi_targets.find_by(:iscsi_name => "new_target")
      new_lun = ems.miq_scsi_luns.find_by(:device_name => "new_lun")
      aggregate_failures "after" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(3)
        expect(new_target.miq_scsi_luns.size).to eq(1)
        expect(new_target.guest_device_id).to eq(guest_device2s.id)
        expect(new_lun.miq_scsi_target_id).to eq(new_target.id)
      end
    end

    it "deletes a scsi target/lun" do
      h = rebuild_hardware(hardware2)
      hardware2.guest_devices.each do |g|
        inv_gd = parser.persister.guest_devices.build(
          :hardware        => h,
          :uid_ems         => g.uid_ems,
          :ems_ref         => g.ems_ref,
          :device_type     => g.device_type,
          :controller_type => g.controller_type,
          :auto_detect     => g.auto_detect,
          :address         => g.address,
          :location        => g.location,
          :filename        => g.filename,
          :model           => g.model
        )
        g.miq_scsi_targets.reject { |s| s.iscsi_name == "TARGET20" }.each do |t|
          inv_t = parser.persister.miq_scsi_targets.build(
            :guest_device => inv_gd,
            :iscsi_name   => t.iscsi_name,
            :uid_ems      => t.uid_ems
          )
          t.miq_scsi_luns.each do |l|
            parser.persister.miq_scsi_luns.build(
              :miq_scsi_target => inv_t,
              :canonical_name  => l.canonical_name,
              :device_name     => l.device_name,
              :device_type     => l.device_type,
              :capacity        => l.capacity,
              :uid_ems         => l.uid_ems
            )
          end
        end
      end
      aggregate_failures "before" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
      end
      parser.persister.persist!
      vios2.reload
      ems.reload
      guest_device2s.reload
      aggregate_failures "after" do
        expect { miq_scsci_target20.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { miq_scsci_lun20.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(1)
      end
    end

    it "modifies a scsi target/lun" do
      h = rebuild_hardware(hardware2)
      hardware2.guest_devices.each do |g|
        inv_gd = parser.persister.guest_devices.build(
          :hardware        => h,
          :uid_ems         => g.uid_ems,
          :ems_ref         => g.ems_ref,
          :device_type     => g.device_type,
          :controller_type => g.controller_type,
          :auto_detect     => g.auto_detect,
          :address         => g.address,
          :location        => g.location,
          :filename        => g.filename,
          :model           => g.model
        )
        g.miq_scsi_targets.each do |t|
          inv_t = parser.persister.miq_scsi_targets.build(
            :guest_device => inv_gd,
            :iscsi_name   => t.iscsi_name == "TARGET20" ? "modified_target" : t.iscsi_name,
            :uid_ems      => t.uid_ems
          )
          t.miq_scsi_luns.each do |l|
            parser.persister.miq_scsi_luns.build(
              :miq_scsi_target => inv_t,
              :canonical_name  => l.canonical_name,
              :device_name     => t.iscsi_name == "TARGET20" ? "modified_device" : l.device_name,
              :device_type     => l.device_type,
              :capacity        => l.capacity,
              :uid_ems         => l.uid_ems
            )
          end
        end
      end
      aggregate_failures "before" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
      end
      parser.persister.persist!
      vios2.reload
      ems.reload
      guest_device2s.reload
      miq_scsci_target20.reload
      miq_scsci_lun20.reload
      aggregate_failures "after" do
        expect(vios2.hardware.guest_devices.size).to eq(4)
        expect(guest_device2s.miq_scsi_targets.size).to eq(2)
        expect(miq_scsci_target20.iscsi_name).to eq("modified_target")
        expect(miq_scsci_target20.guest_device_id).to eq(guest_device2s.id)
        expect(miq_scsci_lun20.device_name).to eq("modified_device")
        expect(miq_scsci_lun20.miq_scsi_target_id).to eq(miq_scsci_target20.id)
      end
    end
  end
end
