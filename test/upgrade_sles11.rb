require_relative "../helper/spec_helper.rb"

describe "SLES11 - SLES12 upgrade checks," do
  it "if user -vagrant- has been created" do
    run_test_script("user.sh")
  end

  # bnc #878427
  it "if root has /root home" do
    run_test_script("root.sh")
  end

  it "if dns server and network is available" do
    run_test_script("dns.sh")
  end

  # bnc #887126
  it "if no tmpfs device in autoinst.xml" do
    run_test_script("tmpfs.sh")
  end

  # bnc #888168
  it "if registration is not in autoinst.xml" do
    run_test_script("no_registration.sh")
  end

  # bnc #935066
  it "if ntp time syncing has been passed" do
    run_test_script("ntp_sync.sh")
  end

  it "if user scripts have been run" do
    run_test_script("autoupgrade-userscr.sh")
  end

end
