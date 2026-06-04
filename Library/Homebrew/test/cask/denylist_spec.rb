# typed: false
# frozen_string_literal: true

require "cask/denylist"

RSpec.describe Cask::Denylist, :cask do
  let(:klass) { Cask::Denylist }

  describe "::reason" do
    matcher :disallow do |name|
      match do |expected|
        expected.reason(name)
      end
    end

    specify(:aggregate_failures) do
      expect(klass).not_to disallow("adobe-air")
      expect(klass).to disallow("adobe-after-effects")
      expect(klass).to disallow("adobe-illustrator")
      expect(klass).to disallow("adobe-indesign")
      expect(klass).to disallow("adobe-photoshop")
      expect(klass).to disallow("adobe-premiere")
      expect(klass).to disallow("pharo")
      expect(klass).not_to disallow("allowed-cask")
    end
  end
end
