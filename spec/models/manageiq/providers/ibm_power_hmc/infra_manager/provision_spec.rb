describe ManageIQ::Providers::IbmPowerHmc::InfraManager::Provision do
  let(:admin)    { FactoryBot.create(:user_with_group) }
  let(:ems)      { FactoryBot.create(:ems_ibm_power_hmc_infra_with_authentication) }
  let(:host)     { FactoryBot.create(:ibm_power_hmc_host, :ext_management_system => ems, :ems_ref => "host1_uuid", :name => "host1") }
  let(:vm)       { FactoryBot.create(:ibm_power_hmc_lpar, :ext_management_system => ems, :ems_ref => "vm1_uuid", :name => "vm1", :host => host) }
  let(:template) { FactoryBot.create(:ibm_power_hmc_template, :ext_management_system => ems, :ems_ref => "template1_uuid", :name => "template1") }

  context "provisioning" do
    let(:pr) do
      FactoryBot.create(:miq_provision_request, :requester => admin, :src_vm_id => template.id)
    end
    let(:prov) do
      FactoryBot.create(
        :ibm_power_hmc_miq_provision,
        :userid       => admin.userid,
        :miq_request  => pr,
        :source       => template,
        :request_type => 'template',
        :state        => 'pending',
        :status       => 'Ok',
        :options      => {:src_vm_id => [template.id, template.name]}
      )
    end

    it "destination_type" do
      expect(prov.destination_type).to eq("Vm")
    end
    it "find_destination_in_vmdb" do
      expect(prov.find_destination_in_vmdb(vm.ems_ref).ems_ref).to eq(vm.ems_ref)
    end
    it "start_clone" do
      allow_any_instance_of(template.class).to receive(:provision_lpar).and_return(nil)
      expect_any_instance_of(template.class).to receive(:provision_lpar)
      prov.start_clone({})
    end

    context "prepare_for_clone_task with storage overrides" do
      before do
        prov.options[:placement_host_name] = [host.id, host.name]
        prov.options[:vlan]                = "lan_A"
        prov.options[:vscsi_storage]       = "vios1:hdisk10"
        prov.options[:vfc_storage]         = "vios1:fcs0"
      end

      it "includes the host, vlan and storage overrides in clone options" do
        clone_opts = prov.prepare_for_clone_task
        expect(clone_opts).to include(
          :host_id       => host.id,
          :vlan          => "lan_A",
          :vscsi_storage => "vios1:hdisk10",
          :vfc_storage   => "vios1:fcs0"
        )
      end

      it "sets the storage keys to nil when they are not in the options" do
        prov.options.delete(:vscsi_storage)
        prov.options.delete(:vfc_storage)
        clone_opts = prov.prepare_for_clone_task
        expect(clone_opts).to include(:vscsi_storage => nil, :vfc_storage => nil)
      end

      it "logs the storage overrides" do
        clone_opts = prov.prepare_for_clone_task
        allow($ibm_power_hmc_log).to receive(:info)
        prov.log_clone_options(clone_opts)

        expect($ibm_power_hmc_log).to have_received(:info).with(/vSCSI Storage Override:\s+\[vios1:hdisk10\]/)
        expect($ibm_power_hmc_log).to have_received(:info).with(/vFC Storage Override:\s+\[vios1:fcs0\]/)
      end
    end
  end

  context "publish" do
    let(:pr) do
      FactoryBot.create(:miq_provision_request, :requester => admin, :src_vm_id => vm.id)
    end
    let(:prov) do
      FactoryBot.create(
        :ibm_power_hmc_miq_provision,
        :userid       => admin.userid,
        :miq_request  => pr,
        :source       => vm,
        :request_type => 'clone_to_template',
        :state        => 'pending',
        :status       => 'Ok',
        :options      => {:src_vm_id => [vm.id, vm.name]}
      )
    end

    it "destination_type" do
      expect(prov.destination_type).to eq("Template")
    end
    it "find_destination_in_vmdb" do
      expect(prov.find_destination_in_vmdb(template.ems_ref).ems_ref).to eq(template.ems_ref)
    end
    it "start_clone" do
      allow_any_instance_of(vm.class).to receive(:make_template).and_return(nil)
      expect_any_instance_of(vm.class).to receive(:make_template)
      prov.start_clone({})
    end
  end

  context "clone" do
    let(:pr) do
      FactoryBot.create(:miq_provision_request, :requester => admin, :src_vm_id => template.id)
    end
    let(:prov) do
      FactoryBot.create(
        :ibm_power_hmc_miq_provision,
        :userid       => admin.userid,
        :miq_request  => pr,
        :source       => template,
        :request_type => 'clone_to_template',
        :state        => 'pending',
        :status       => 'Ok',
        :options      => {:src_vm_id => [template.id, template.name]}
      )
    end

    it "destination_type" do
      expect(prov.destination_type).to eq("Template")
    end
    it "find_destination_in_vmdb" do
      expect(prov.find_destination_in_vmdb(template.ems_ref).ems_ref).to eq(template.ems_ref)
    end
    it "start_clone" do
      allow_any_instance_of(template.class).to receive(:make_clone).and_return(nil)
      expect_any_instance_of(template.class).to receive(:make_clone)
      prov.start_clone({})
    end
  end

  context "provision_error" do
    let(:pr) { FactoryBot.create(:miq_provision_request, :requester => admin, :src_vm_id => template.id) }
    let(:request_type) { 'template' }
    let(:prov) do
      FactoryBot.create(
        :ibm_power_hmc_miq_provision,
        :userid       => admin.userid,
        :miq_request  => pr,
        :source       => template,
        :request_type => request_type,
        :state        => 'active',
        :status       => 'Ok',
        :options      => {:src_vm_id => [template.id, template.name], :vm_name => "vm1"}
      )
    end
    let(:long_text) { "#{'x' * 300} the reason the HMC gave" }

    def fail_with(message, exception_class: "ManageIQ::Providers::IbmPowerHmc::HmcJobError")
      prov.phase_context[:exception_class]   = exception_class
      prov.phase_context[:exception_message] = message
      prov.phase_context[:error_phase]       = "poll_clone_complete"
    end

    before { allow(prov).to receive(:signal) } # signal :finish is not what is tested here

    it "keeps the full text in options[:error_detail]" do
      fail_with(long_text, :exception_class => "RuntimeError")
      prov.provision_error
      expect(prov.reload.options[:error_detail]).to eq("[RuntimeError]: #{long_text}")
    end

    it "leaves the task message, state and status as ManageIQ sets them (message still cut to 255)" do
      fail_with(long_text, :exception_class => "RuntimeError")
      prov.provision_error
      prov.reload
      expect(prov.message).to eq("[RuntimeError]: #{long_text}"[0, 255])
      expect(prov.state).to eq("finished")
      expect(prov.status).to eq("Error")
    end

    it "does not change the other options" do
      fail_with("boom", :exception_class => "RuntimeError")
      prov.provision_error
      expect(prov.reload.options).to include(:vm_name => "vm1", :src_vm_id => [template.id, template.name])
    end

    it "uses error_message when the phase set one" do
      prov.phase_context[:error_message] = "explicit failure"
      prov.provision_error
      expect(prov.reload.options[:error_detail]).to eq("explicit failure")
    end

    it "caps the stored text" do
      fail_with("y" * 10_000, :exception_class => "RuntimeError")
      prov.provision_error
      expect(prov.reload.options[:error_detail].length).to eq(described_class::ERROR_DETAIL_MAX_LENGTH)
    end

    it "stores nothing when there is no error text" do
      prov.provision_error
      expect(prov.reload.options).not_to have_key(:error_detail)
    end

    it "still runs the ManageIQ error handling and signals :finish when storing fails" do
      fail_with("boom", :exception_class => "RuntimeError")
      allow(prov).to receive(:update!).and_call_original
      allow(prov).to receive(:update!).with(hash_including(:options)).and_raise(ActiveRecord::RecordInvalid)
      expect(prov).to receive(:signal).with(:finish)
      expect { prov.provision_error }.not_to raise_error
      prov.reload
      expect(prov.state).to eq("finished")
      expect(prov.status).to eq("Error")
      expect(prov.message).to eq("[RuntimeError]: boom")
      expect(prov.options).not_to have_key(:error_detail)
    end

    it "does not raise even when logging the failure fails" do
      fail_with("boom", :exception_class => "RuntimeError")
      allow(prov).to receive(:update!).and_call_original

      allow(prov).to receive(:update!).with(hash_including(:options)).and_raise(StandardError)
      allow($ibm_power_hmc_log).to receive(:warn).and_raise(StandardError)
      expect { prov.provision_error }.not_to raise_error
    end

    context "when publishing a template (clone_to_template)" do
      let(:request_type) { 'clone_to_template' }

      it "does not store error_detail" do
        fail_with(long_text, :exception_class => "RuntimeError")
        prov.provision_error
        prov.reload
        expect(prov.options).not_to have_key(:error_detail)
        expect(prov.message).to eq("[RuntimeError]: #{long_text}"[0, 255])
      end
    end
  end
end
