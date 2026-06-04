# typed: false

cask "on-linux-asymmetric" do
  arch arm: "arm", intel: "intel"
  os macos: "darwin", linux: "linux"

  version "1.2.3"

  url "file://#{TEST_FIXTURE_DIR}/cask/caffeine-#{arch}-#{os}.zip"
  homepage "https://brew.sh/"

  on_macos do
    sha256 arm:   "67cdb8a02803ef37fdbf7e0be205863172e41a561ca446cd84f0d7ab35a99d94",
           intel: "8c62a2b791cf5f0da6066a0a4b6e85f62949cd60975da062df44adf887f4370b"
  end

  on_linux do
    sha256 x86_64_linux: "8c62a2b791cf5f0da6066a0a4b6e85f62949cd60975da062df44adf887f4370b"

    depends_on arch: :x86_64
  end

  app "Caffeine.app"
end
