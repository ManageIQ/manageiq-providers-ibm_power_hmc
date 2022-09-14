class ManageIQ::Providers::IbmPowerHmc::Inventory::Parser::TargetCollection < ManageIQ::Providers::IbmPowerHmc::Inventory::Parser::InfraManager
  def parse_lpar_disks(lpar, hardware)
    collector.manager.vms.find_by(:ems_ref => lpar.uuid).try do |vm|
      vm.hardware.disks.each do |disk|
        persister.disks.build(
          :device_type     => disk.device_type,
          :hardware        => hardware,
          :storage         => disk.storage,
          :device_name     => disk.device_name,
          :size            => disk.size,
          :controller_type => disk.controller_type,
          :location        => disk.location,
          :backing         => disk.backing
        )
      end
    end
  end
end
