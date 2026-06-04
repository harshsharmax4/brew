# typed: true
# frozen_string_literal: true

require_relative "shared_examples"

RSpec.describe UnpackStrategy::Dmg, :needs_macos do
  describe "#mount" do
    let(:path) { TEST_FIXTURE_DIR/"cask/container.dmg" }

    include_examples "UnpackStrategy::detect"

    specify "#extract" do
      Dir.mktmpdir do |dir|
        unpack_dir = Pathname(dir)
        mount = instance_double(UnpackStrategy::Dmg.const_get(:Mount, false))
        unpack_strategy = UnpackStrategy::Dmg.new(path)

        allow(unpack_strategy).to receive(:mount).with(verbose: false).and_yield([mount])
        allow(mount).to receive(:extract).with(to: unpack_dir, verbose: false) do
          (unpack_dir/"container").mkpath
        end

        unpack_strategy.extract(to: unpack_dir)
        expect(unpack_dir.children(false).map(&:to_s)).to contain_exactly("container")
      end
    end
  end
end
