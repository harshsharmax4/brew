# typed: false
# frozen_string_literal: true

require "bundle_version"

RSpec.describe Homebrew::BundleVersion do
  let(:klass) { Homebrew::BundleVersion }

  describe "#<=>" do
    it "compares both the `short_version` and `version`" do
      expect(klass.new("1.2.3", "3000")).to be < klass.new("1.2.3", "4000")
      expect(klass.new("1.2.3", "4000")).to be <= klass.new("1.2.3", "4000")
      expect(klass.new("1.2.3", "4000")).to be >= klass.new("1.2.3", "4000")
      expect(klass.new("1.2.4", "4000")).to be > klass.new("1.2.3", "4000")
    end

    it "compares `version` first" do
      expect(klass.new("1.2.4", "3000")).to be < klass.new("1.2.3", "4000")
    end

    it "does not fail when `short_version` or `version` is missing" do
      expect(klass.new("1.06", nil)).to be < klass.new("1.12", "1.12")
      expect(klass.new("1.06", "471")).to be > klass.new(nil, "311")
      expect(klass.new("1.2.3", nil)).to be < klass.new("1.2.4", nil)
      expect(klass.new(nil, "1.2.3")).to be < klass.new(nil, "1.2.4")
      expect(klass.new("1.2.3", nil)).to be < klass.new(nil, "1.2.3")
      expect(klass.new(nil, "1.2.3")).to be > klass.new("1.2.3", nil)
    end
  end

  describe "#nice_version" do
    expected_mappings = {
      ["1.2", nil]            => "1.2",
      [nil, "1.2.3"]          => "1.2.3",
      ["1.2", "1.2.3"]        => "1.2.3",
      ["1.2.3", "1.2"]        => "1.2.3",
      ["1.2.3", "8312"]       => "1.2.3,8312",
      ["2021", "2006"]        => "2021,2006",
      ["1.0", "1"]            => "1.0",
      ["1.0", "0"]            => "1.0",
      ["1.2.3.4000", "4000"]  => "1.2.3.4000",
      ["5", "5.0.45"]         => "5.0.45",
      ["2.5.2(3329)", "3329"] => "2.5.2,3329",
    }

    expected_mappings.each do |(short_version, version), expected_version|
      it "maps (#{short_version.inspect}, #{version.inspect}) to #{expected_version.inspect}" do
        expect(klass.new(short_version, version).nice_version)
          .to eq expected_version
      end
    end
  end

  describe "#to_h" do
    it "returns a hash containing non-nil instance variables" do
      expect(klass.new("1.2.3", "3000").to_h)
        .to eq({ short_version: "1.2.3", version: "3000" })
      expect(klass.new(nil, "3000").to_h)
        .to eq({ version: "3000" })
      expect(klass.new("1.2.3", nil).to_h)
        .to eq({ short_version: "1.2.3" })
    end
  end
end
