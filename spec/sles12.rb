require_relative "../helper/spec_helper.rb"

describe "SLES 12 checks," do
  it "if user -vagrant- has been created" do
    run_test_script("user.sh")
  end

  # bnc #878427
  it "if root has /root home" do
    run_test_script("root.sh")
  end

  it "if files can be downloaded from tftp server" do
    run_test_script("tftp.sh")
  end

  it "if dns server and network is available" do
    run_test_script("dns.sh")
  end

  it "if user scripts have been run" do
    run_test_script("autoinst-userscr.sh")
  end

  # bnc #886808
  it "if partition_id order fits" do
    run_test_script("partition.sh")
  end

  # bnc #887126
  it "if no tmpfs device in autoinst.xml" do
    run_test_script("tmpfs.sh")
  end

  # bnc #882982
  # Due bug #935769 it fails currently
#  it "if subvolumes are correctly in autoinst.xml" do
#    run_test_script("subvolumes.sh")
#  end

  # bnc #888168
  it "if registration is not in autoinst.xml" do
    run_test_script("no_registration.sh")
  end

  it "after installation snapshot has been created" do
    run_test_script("installation_snapshot.sh")
  end
end
