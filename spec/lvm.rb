require_relative "../helper/spec_helper.rb"

describe "LVM partition;" do

  before(:all) do
    # Start the previously create vagrant VM - opensuse_vm. 
    $vm = start_system(box: "autoyast_vm")
  end

  it "creates lvm partitions" do
    run_test_script("lvm.sh")
  end

  # bnc #891808
  it "sets default keyboard " do
    run_test_script("keyboard.sh")
  end

  # bnc #928987
  it "sets peer/restrict in autoinst.xml by using default ntp.conf" do
    run_test_script("ntp.sh")
  end

  after(:all) do
    # Shutdown the vagrant box.
    $vm.stop
  end
end
