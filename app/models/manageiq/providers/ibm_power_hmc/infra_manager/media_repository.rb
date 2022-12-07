class ManageIQ::Providers::IbmPowerHmc::InfraManager::MediaRepository < ManageIQ::Providers::IbmPowerHmc::InfraManager::Storage
  supports :iso_datastore

  def self.display_name(number = 1)
    n_("Media Repository", "Media Repositories", number)
  end
end
