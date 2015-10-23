require_relative "spec_helper"

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
  it "if subvolumes are correctly in autoinst.xml" do
    run_test_script("subvolumes.sh")
  end

  # bnc #888168
  it "if registration is not in autoinst.xml" do
    run_test_script("no_registration.sh")
  end

  # bnc #935066
  it "if ntp time syncing has been passed" do
    run_test_script("ntp_sync.sh")
  end

  it "after installation snapshot has been created" do
    run_test_script("installation_snapshot.sh")
  end

  # fate #319086
  it "do not reinstall packages in the second stage" do
    run_test_script("no_reinstall.sh")
  end

  # bnc #941948
  it "all expected sections are present in autoinst.xml" do
    run_test_script("profile_sections.sh")
  end

  # bsc #948608
  it "handles zypper's pkgGpgCheck callback during installation" do
    run_test_script("handle_zypper_pkg_gpg_check.sh")
  end

end
