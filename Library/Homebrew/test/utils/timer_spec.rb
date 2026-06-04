# typed: true
# frozen_string_literal: true

require "utils/timer"

RSpec.describe Utils::Timer do
  let(:klass) { Utils::Timer }

  describe "#remaining" do
    it "returns nil when nil" do
      expect(klass.remaining(nil)).to be_nil
    end

    it "returns time remaining when there is time remaining" do
      expect(klass.remaining(Time.now + 10)).to be > 1
    end

    it "returns 0 when there is no time remaining" do
      expect(klass.remaining(Time.now - 10)).to be 0
    end
  end

  describe "#remaining!" do
    it "returns nil when nil" do
      expect(klass.remaining!(nil)).to be_nil
    end

    it "returns time remaining when there is time remaining" do
      expect(klass.remaining!(Time.now + 10)).to be > 1
    end

    it "returns 0 when there is no time remaining" do
      expect { klass.remaining!(Time.now - 10) }.to raise_error(Timeout::Error)
    end
  end
end
