require_relative "spec_helper"

describe "SLES 12 checks," do
  it "if user -vagrant- has been created" do
    run_test_script("user.sh")
  end

  # bnc #878427
  it "if root has /root home" do
    run_test_script("root.sh")
  end

  it "after installation snapshot has been created" do
    run_test_script("installation_snapshot.sh")
  end

  it "YaST2 packages are not installed" do
    run_test_script("no_yast2_packages.sh")
  end

  it "second stage was not executed" do
    run_test_script("no_second_stage.sh")
  end
end
