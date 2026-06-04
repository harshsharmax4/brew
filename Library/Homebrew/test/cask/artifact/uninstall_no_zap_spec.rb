# typed: true
# frozen_string_literal: true

RSpec.describe Cask::Artifact::Zap, :cask do
  let(:klass) { Cask::Artifact::Zap }

  let(:cask) { Cask::CaskLoader.load(cask_path("with-installable")) }

  let(:zap_artifact) do
    cask.artifacts.find { |a| a.is_a?(klass) }
  end

  before do
    InstallHelper.install_without_artifacts(cask)
  end

  describe "#uninstall_phase" do
    subject { zap_artifact }

    it { is_expected.not_to respond_to(:uninstall_phase) }
  end
end
