# typed: true
# frozen_string_literal: true

require "requirements/linux_requirement"

RSpec.describe LinuxRequirement do
  subject(:requirement) { klass.new }

  let(:klass) { LinuxRequirement }

  describe "#satisfied?" do
    it "returns true on Linux" do
      expect(requirement.satisfied?).to eq(OS.linux?)
    end
  end
end
