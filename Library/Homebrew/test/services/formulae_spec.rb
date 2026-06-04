# typed: strict
# frozen_string_literal: true

require "services/formulae"

RSpec.describe Homebrew::Services::Formulae do
  sig { returns(T.class_of(Homebrew::Services::Formulae)) }
  let(:klass) { Homebrew::Services::Formulae }

  describe "#services_list" do
    it "empty list without available formulae" do
      allow(klass).to receive(:available_services).and_return({})
      expect(klass.services_list).to eq([])
    end

    it "list with available formulae" do
      formula = instance_double(Homebrew::Services::FormulaWrapper)
      expected = [
        {
          file:   Pathname.new("/Library/LaunchDaemons/file.plist"),
          name:   "formula",
          status: :known,
          user:   "root",
        },
      ]

      expect(formula).to receive(:to_hash).and_return(expected[0])
      allow(klass).to receive(:available_services).and_return([formula])
      expect(klass.services_list).to eq(expected)
    end
  end
end
