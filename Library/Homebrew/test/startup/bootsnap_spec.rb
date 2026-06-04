# typed: strict
# frozen_string_literal: true

RSpec.describe Homebrew::Bootsnap do
  describe "::load!" do
    it "does not error when the configured gem path is unavailable" do
      with_env(HOMEBREW_BOOTSNAP_GEM_PATH: "#{TEST_TMPDIR}/missing-bootsnap", HOMEBREW_NO_BOOTSNAP: nil) do
        expect { Homebrew::Bootsnap.load! }.not_to raise_error
      end
    end
  end
end
