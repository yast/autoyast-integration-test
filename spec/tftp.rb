require_relative "../helper/spec_helper.rb"

describe "SLES 12 TFTP server " do

  before(:all) do
    # Start the previously create vagrant VM - opensuse_vm. 
    $vm = start_system(box: "autoyast_vm")
  end

  it "checks, tftp is running correctly" do
    run_test_script("tftp.sh")
  end

  # bug 870998
  it "checks, if host is in /etc/hosts" do
    run_test_script("host.sh")
  end

  after(:all) do
    # Shutdown the vagrant box.
    $vm.stop
  end
end
