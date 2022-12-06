class ManageIQ::Providers::IbmPowerHmc::InfraManager::MediaRepository < ManageIQ::Providers::IbmPowerHmc::InfraManager::Storage
  supports :iso_datastore

  belongs_to :ext_management_system, :foreign_key => :ems_id

  def self.display_name(number = 1)
    n_("Media Repository", "Media Repositories", number)
  end
end
