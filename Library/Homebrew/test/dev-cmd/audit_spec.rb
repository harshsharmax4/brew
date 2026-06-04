# typed: true
# frozen_string_literal: true

require "dev-cmd/audit"
require "cmd/shared_examples/args_parse"

RSpec.describe Homebrew::DevCmd::Audit do
  let(:klass) { Homebrew::DevCmd::Audit }

  it_behaves_like "parseable arguments"

  describe "#run" do
    subject(:audit) { klass.new(["--tap=homebrew/test"]) }

    let(:tap_path) { mktmpdir }
    let(:macos_only_cask_file) { tap_path/"Casks/macos-only-example.rb" }
    let(:linux_cask_file) { tap_path/"Casks/linux-example.rb" }
    let(:tap) { instance_double(Tap, formula_files: [], cask_files: [macos_only_cask_file, linux_cask_file]) }

    before do
      macos_only_cask_file.dirname.mkpath
      macos_only_cask_file.write <<~RUBY
        cask "macos-only-example" do
          version "1.0"
          sha256 arm:   "0000000000000000000000000000000000000000000000000000000000000000",
                 intel: "1111111111111111111111111111111111111111111111111111111111111111"
          url "https://example.invalid/x.pkg"
          name "Example"
          desc "macOS-only cask"
          homepage "https://example.invalid/"
          depends_on macos: ">= :ventura"
          binary "x"
        end
      RUBY
      linux_cask_file.write <<~RUBY
        cask "linux-example" do
          version "1.0"
          sha256 arm:   "0000000000000000000000000000000000000000000000000000000000000000",
                 intel: "1111111111111111111111111111111111111111111111111111111111111111"
          url "https://example.invalid/x.tar.gz"
          name "Example"
          desc "Linux-supported cask"
          homepage "https://example.invalid/"
          binary "x"
        end
      RUBY

      allow(Homebrew).to receive(:install_bundler_gems!)
      ENV.activate_extensions!
      allow(ENV).to receive(:setup_build_environment)
      allow(Tap).to receive(:fetch).and_call_original
      allow(Tap).to receive(:fetch).with("homebrew/test").and_return(tap)
      allow(Tap).to receive(:installed).and_return([])
    end

    it "skips macOS-only casks when loading tap casks on Linux" do
      Homebrew::SimulateSystem.with(os: :linux) do
        expect { audit.run }.to raise_error(Cask::CaskInvalidError, /linux-example.*invalid 'sha256'/)
      end
    end
  end
end
