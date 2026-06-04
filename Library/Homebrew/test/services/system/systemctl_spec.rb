# typed: true
# frozen_string_literal: true

require "services/system"
require "services/system/systemctl"

RSpec.describe Homebrew::Services::System::Systemctl do
  let(:klass) { Homebrew::Services::System::Systemctl }

  let(:bindir) { mktmpdir }

  describe ".scope" do
    it "outputs systemctl scope for user" do
      allow(Homebrew::Services::System).to receive(:root?).and_return(false)
      expect(klass.scope).to eq("--user")
    end

    it "outputs systemctl scope for root" do
      allow(Homebrew::Services::System).to receive(:root?).and_return(true)
      expect(klass.scope).to eq("--system")
    end
  end

  describe ".executable" do
    it "outputs systemctl command location" do
      systemctl = bindir/"systemctl"
      systemctl.write <<~SH
        #!/bin/sh
        exit 0
      SH
      systemctl.chmod 0755
      klass.reset_executable!

      with_env(PATH: bindir.to_s) do
        expect(klass.executable).to eq(systemctl)
      end
    end
  end
end
