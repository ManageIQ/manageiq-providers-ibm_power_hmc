class ManageIQ::Providers::IbmPowerHmc::InfraManager::RefreshWorker < MiqEmsRefreshWorker
  class << self
    def all_valid_ems_in_zone
      super.reject(&:parent_manager)
    end
  end
end
