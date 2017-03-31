require "spec_helper"
require "aytests/vagrant_runner"

RSpec.describe AYTests::VagrantRunner do
  VM_NAME = AYTests::VagrantRunner::VM_NAME
  let(:vagrantfile) { Pathname.new(__FILE__).dirname.join("..", "share", "vagrant", "Vagrantfile") }
  let(:dir) { TEST_WORK_DIR.join("vagrant") }
  let(:provider) { :libvirt }
  subject(:runner) { AYTests::VagrantRunner.new(vagrantfile, dir, provider) }

  describe "#start" do
    before(:each) do
      allow(FileUtils).to receive(:cp).with(vagrantfile, dir).and_call_original
    end

    context "when provider is :libvirt" do
      it "starts the machine using :libvirt provider and generates the ssh configuration" do
        expect(runner).to receive(:system).with("vagrant up autoyast_vm --provider libvirt")
        expect(runner).to receive(:system).with("vagrant ssh-config > #{runner.ssh_config}")
        expect(runner).to receive(:system).with("vagrant ssh -c 'true'").and_return(true)
        expect(runner.start).to eq(true)
      end
    end

    context "when provider is :virtualbox" do
      let(:provider) { :virtualbox }

      it "starts the machine using :virtualbox provider and generates the ssh configuration" do
        expect(runner).to receive(:system).with("vagrant up autoyast_vm --provider virtualbox")
        expect(runner).to receive(:system).with("vagrant ssh-config > #{runner.ssh_config}")
        expect(runner).to receive(:system).with("vagrant ssh -c 'true'").and_return(true)
        expect(runner.start).to eq(true)
      end
    end

    context "when the machine is not accessible" do
      it "returns false" do
        allow(runner).to receive(:system).with("vagrant up autoyast_vm --provider libvirt")
        allow(runner).to receive(:system).with("vagrant ssh-config > #{runner.ssh_config}")
        allow(runner).to receive(:system).with("vagrant ssh -c 'true'").and_return(false)
        expect(runner.start).to eq(false)
      end
    end
  end

  describe "#stop" do
    it "stops the machine" do
      FileUtils.mkdir_p(dir)
      expect(runner).to receive(:system).with("vagrant halt")
      runner.stop
    end
  end

  describe "#cleanup" do
    before do
      FileUtils.mkdir_p(dir)
    end

    it "cleans up the machine and the SSH config" do
      expect(runner).to receive(:system).with("vagrant destroy --force")
      expect(FileUtils).to receive(:rm_rf).with(runner.ssh_config)
      runner.cleanup
    end
  end

  describe "#run" do
    let(:script) { "path/to/some/my-script" }
    let(:remote_script) { "/tmp/my-script" }

    it "runs a script on the Vagrant machine" do
      conn = double("conn", close: true)
      expect(Net::SSH::Simple).to receive(:new).and_return(conn)
      expect(conn).to receive(:scp_put)
        .with(VM_NAME, script, remote_script, config: runner.ssh_config)
      expect(conn).to receive(:ssh)
        .with(VM_NAME, "/usr/bin/chmod +x /tmp/my-script")
      expect(conn).to receive(:ssh)
        .with(VM_NAME, "/usr/bin/env #{remote_script}")
      expect(conn).to receive(:ssh)
        .with(VM_NAME, "/usr/bin/rm /tmp/my-script")
      runner.run(script)
    end

    context "when sudo execution is requested" do
      it "runs a script on the vagrant machine using 'sudo'" do
        conn = double("conn", close: true)
        expect(runner).to receive(:with_conn).and_yield(conn)
        expect(conn).to receive(:scp_put)
          .with(VM_NAME, script, remote_script, config: runner.ssh_config)
        expect(conn).to receive(:ssh)
          .with(VM_NAME, "/usr/bin/chmod +x /tmp/my-script")
        expect(conn).to receive(:ssh)
          .with(VM_NAME, "sudo /usr/bin/env #{remote_script}")
        expect(conn).to receive(:ssh)
          .with(VM_NAME, "/usr/bin/rm /tmp/my-script")
        runner.run(script, sudo: true)
      end
    end
  end
end
