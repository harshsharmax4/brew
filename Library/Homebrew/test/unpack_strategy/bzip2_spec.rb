# typed: true
# frozen_string_literal: true

require_relative "shared_examples"

RSpec.describe UnpackStrategy::Bzip2 do
  let(:path) { TEST_FIXTURE_DIR/"cask/container.bz2" }

  include_examples "UnpackStrategy::detect"
  include_examples "#extract", children: ["container"]

  it "extracts with bzip2" do
    strategy = UnpackStrategy::Bzip2.new(path)

    Dir.mktmpdir do |dir|
      unpack_dir = Pathname(dir)
      target = unpack_dir/path.basename
      expect(strategy).to receive(:system_command!).with(
        "bzip2",
        args:    ["-q", "-d", target],
        env:     { "PATH" => an_instance_of(PATH) },
        verbose: false,
      )

      strategy.extract(to: unpack_dir)
    end
  end
end
