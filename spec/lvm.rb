require_relative "../helper/spec_helper.rb"

describe "LVM partition;" do

  before(:all) do
    # Start the previously create vagrant VM - opensuse_vm. 
    $vm = start_system(box: "autoyast_vm")
  end

  it "checks if lvm partitions have been created" do
    run_test_script("lvm.sh")
  end

  # bnc #891808
  it "checks for default keyboard " do
    run_test_script("keyboard.sh")
  end

  # bnc #928987
  it "checks peer/restrict sections in default ntp.conf" do
    run_test_script("ntp.sh")
  end

  after(:all) do
    # Shutdown the vagrant box.
    $vm.stop
  end
end
