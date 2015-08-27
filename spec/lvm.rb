require_relative "../helper/spec_helper.rb"

describe "LVM partition;" do
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

  # bnc #897129
  it "sets firewall with exisiting network (keep_install_network)" do
    run_test_script("firewall.sh")
  end

  it "after installation snapshot has been created" do
    run_test_script("installation_snapshot.sh")
  end

end
