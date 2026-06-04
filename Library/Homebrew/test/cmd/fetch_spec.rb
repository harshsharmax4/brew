# typed: strict
# frozen_string_literal: true

require "cmd/fetch"
require "cmd/shared_examples/args_parse"

RSpec.describe Homebrew::Cmd::FetchCmd do
  it_behaves_like "parseable arguments"

  it "downloads Formula and Cask URLs concurrently", :cask, :integration_test do
    setup_test_formula "testball1"
    setup_test_formula "testball2"

    expect { brew "fetch", "testball1", "testball2", "local-caffeine" }.to be_a_success

    expect(HOMEBREW_CACHE/"testball1--0.1.tbz").to be_a_symlink
    expect(HOMEBREW_CACHE/"testball1--0.1.tbz").to exist
    expect(HOMEBREW_CACHE/"testball2--0.1.tbz").to be_a_symlink
    expect(HOMEBREW_CACHE/"testball2--0.1.tbz").to exist
    expect((HOMEBREW_CACHE/"downloads").glob("*--caffeine.zip")).not_to be_empty
  end

  describe "#cask_downloads", :cask do
    it "collects one download per distinct URL across all platforms" do
      cmd = Homebrew::Cmd::FetchCmd.new(["--cask", "--all-platforms", "sha256-os"])
      basenames = cmd.send(:cask_downloads, Cask::CaskLoader.load("sha256-os"))
                     .map { |download| File.basename(download.url.to_s) }
      expect(basenames).to contain_exactly("caffeine-arm-darwin.zip", "caffeine-intel-darwin.zip",
                                           "caffeine-arm-linux.zip", "caffeine-intel-linux.zip")
    end

    it "collapses to a single download for a cask without on_system blocks" do
      cmd = Homebrew::Cmd::FetchCmd.new(["--cask", "--all-platforms", "local-caffeine"])
      expect(cmd.send(:cask_downloads, Cask::CaskLoader.load("local-caffeine")).length).to eq(1)
    end
  end
end
