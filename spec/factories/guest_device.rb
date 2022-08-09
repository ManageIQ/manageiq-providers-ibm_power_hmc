FactoryBot.define do
  factory :ibm_power_hmc_guest_device_vfc, :parent => :guest_device do
    device_type            { "storage" }
    controller_type        { "server vfc storage adapter" }
    sequence(:uid_ems)     { |n| "VFC_#{n}" }
  end
end

FactoryBot.define do
  factory :ibm_power_hmc_guest_device_vscsi, :parent => :guest_device do
    device_type            { "storage" }
    controller_type        { "server vscsi storage adapter" }
    sequence(:uid_ems)     { |n| "VSCSI_#{n}" }
  end
end
