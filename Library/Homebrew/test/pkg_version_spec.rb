# typed: true
# frozen_string_literal: true

require "pkg_version"

RSpec.describe PkgVersion do
  let(:klass) { PkgVersion }

  describe "::parse" do
    it "parses versions from a string" do
      expect(klass.parse("1.0_1")).to eq(klass.new(Version.new("1.0"), 1))
      expect(klass.parse("1.0_1")).to eq(klass.new(Version.new("1.0"), 1))
      expect(klass.parse("1.0")).to eq(klass.new(Version.new("1.0"), 0))
      expect(klass.parse("1.0_0")).to eq(klass.new(Version.new("1.0"), 0))
      expect(klass.parse("2.1.4_0")).to eq(klass.new(Version.new("2.1.4"), 0))
      expect(klass.parse("1.0.1e_1")).to eq(klass.new(Version.new("1.0.1e"), 1))
    end
  end

  specify "#==" do
    expect(klass.parse("1.0_0")).to eq klass.parse("1.0")
    version_to_compare = klass.parse("1.0_1")
    expect(version_to_compare == klass.parse("1.0_1")).to be true
    expect(version_to_compare == klass.parse("1.0_2")).to be false
  end

  describe "#>" do
    it "returns true if the left version is bigger than the right" do
      expect(klass.parse("1.1")).to be > klass.parse("1.0_1")
    end

    it "returns true if the left version is HEAD" do
      expect(klass.parse("HEAD")).to be > klass.parse("1.0")
    end

    it "raises an error if the other side isn't of the same class" do
      expect do
        klass.new(Version.new("1.0"), 0) > Object.new
      end.to raise_error(TypeError)
    end

    it "is not compatible with Version" do
      expect do
        klass.new(Version.new("1.0"), 0) > Version.new("1.0")
      end.to raise_error(TypeError)
    end
  end

  describe "#<" do
    it "returns true if the left version is smaller than the right" do
      expect(klass.parse("1.0_1")).to be < klass.parse("2.0_1")
    end

    it "returns true if the right version is HEAD" do
      expect(klass.parse("1.0")).to be < klass.parse("HEAD")
    end
  end

  describe "#<=>" do
    it "returns nil if the comparison fails" do
      expect(Object.new <=> klass.new(Version.new("1.0"), 0)).to be_nil
    end
  end

  describe "#to_s" do
    it "returns a string of the form 'version_revision'" do
      expect(klass.new(Version.new("1.0"), 0).to_s).to eq("1.0")
      expect(klass.new(Version.new("1.0"), 1).to_s).to eq("1.0_1")
      expect(klass.new(Version.new("1.0"), 0).to_s).to eq("1.0")
      expect(klass.new(Version.new("1.0"), 0).to_s).to eq("1.0")
      expect(klass.new(Version.new("HEAD"), 1).to_s).to eq("HEAD_1")
      expect(klass.new(Version.new("HEAD-ffffff"), 1).to_s).to eq("HEAD-ffffff_1")
    end
  end

  describe "#hash" do
    let(:version_one_revision_one) { klass.new(Version.new("1.0"), 1) }
    let(:version_one_dot_one_revision_one) { klass.new(Version.new("1.1"), 1) }
    let(:version_one_revision_zero) { klass.new(Version.new("1.0"), 0) }

    it "returns a hash based on the version and revision" do
      expect(version_one_revision_one.hash).to eq(klass.new(Version.new("1.0"), 1).hash)
      expect(version_one_revision_one.hash).not_to eq(version_one_dot_one_revision_one.hash)
      expect(version_one_revision_one.hash).not_to eq(version_one_revision_zero.hash)
    end
  end

  describe "#version" do
    it "returns package version" do
      expect(klass.parse("1.2.3_4").version).to eq Version.new("1.2.3")
    end
  end

  describe "#revision" do
    it "returns package revision" do
      expect(klass.parse("1.2.3_4").revision).to eq 4
    end
  end

  describe "#major" do
    it "returns major version token" do
      expect(klass.parse("1.2.3_4").major).to eq Version::Token.create("1")
    end
  end

  describe "#minor" do
    it "returns minor version token" do
      expect(klass.parse("1.2.3_4").minor).to eq Version::Token.create("2")
    end
  end

  describe "#patch" do
    it "returns patch version token" do
      expect(klass.parse("1.2.3_4").patch).to eq Version::Token.create("3")
    end
  end

  describe "#major_minor" do
    it "returns major.minor version" do
      expect(klass.parse("1.2.3_4").major_minor).to eq Version.new("1.2")
    end
  end

  describe "#major_minor_patch" do
    it "returns major.minor.patch version" do
      expect(klass.parse("1.2.3_4").major_minor_patch).to eq Version.new("1.2.3")
    end
  end
end
