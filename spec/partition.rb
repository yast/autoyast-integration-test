require_relative "../helper/spec_helper.rb"

describe "Minimal patition checks," do
  it "if user -vagrant- has been created" do
    run_test_script("user.sh")
  end

  # bnc #941096 two partitions has been generated with no subvolumes.
  it "if partition_id order fits" do
    run_test_script("partition.sh")
  end

end
