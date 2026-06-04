# typed: true
# frozen_string_literal: true

require "lazy_object"

RSpec.describe LazyObject do
  let(:klass) { LazyObject }

  describe "#initialize" do
    it "does not evaluate the block" do
      expect do |block|
        klass.new(&block)
      end.not_to yield_control
    end
  end

  describe "when receiving a message" do
    it "evaluates the block" do
      expect(klass.new { 42 }.to_s).to eq "42"
    end
  end

  describe "#!" do
    it "delegates to the underlying object" do
      expect(!klass.new { false }).to be true
    end
  end

  describe "#!=" do
    it "delegates to the underlying object" do
      expect(klass.new { 42 }).not_to eq 13
    end
  end

  describe "#==" do
    it "delegates to the underlying object" do
      expect(klass.new { 42 }).to eq 42
    end
  end
end
