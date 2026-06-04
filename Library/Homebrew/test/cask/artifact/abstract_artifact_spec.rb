# typed: true
# frozen_string_literal: true

RSpec.describe Cask::Artifact::AbstractArtifact, :cask do
  let(:klass) { Cask::Artifact::AbstractArtifact }

  describe ".read_script_arguments" do
    let(:stanza) { :installer }

    it "accepts a string and uses it as the executable" do
      arguments = "something"

      expect(klass.read_script_arguments(arguments, stanza)).to eq(["something", {}])
    end

    it "accepts a hash with an executable" do
      arguments = { executable: "something" }

      expect(klass.read_script_arguments(arguments, stanza)).to eq(["something", {}])
    end

    it "does not mutate the original arguments in place" do
      arguments = { executable: "something" }
      clone = arguments.dup

      klass.read_script_arguments(arguments, stanza)

      expect(arguments).to eq(clone)
    end
  end
end
