# typed: strict
# frozen_string_literal: true

require "PATH"

RSpec.describe PATH do
  sig { returns(T.class_of(PATH)) }
  let(:klass) { PATH }

  describe "#initialize" do
    it "can take multiple arguments" do
      expect(klass.new("/path1", "/path2")).to eq("/path1:/path2")
    end

    it "can parse a mix of arrays and arguments" do
      expect(klass.new(["/path1", "/path2"], "/path3")).to eq("/path1:/path2:/path3")
    end

    it "splits an existing PATH" do
      expect(klass.new("/path1:/path2")).to eq(["/path1", "/path2"])
    end

    it "removes duplicates" do
      expect(klass.new("/path1", "/path1")).to eq("/path1")
    end
  end

  describe "#to_ary" do
    it "returns a PATH array" do
      expect(klass.new("/path1", "/path2").to_ary).to eq(["/path1", "/path2"])
    end

    it "does not allow mutating the original" do
      path = klass.new("/path1", "/path2")
      path.to_ary << "/path3"

      expect(path).not_to include("/path3")
    end
  end

  describe "#to_str" do
    it "returns a PATH string" do
      expect(klass.new("/path1", "/path2").to_str).to eq("/path1:/path2")
    end
  end

  describe "#prepend" do
    specify(:aggregate_failures) do
      expect(klass.new("/path1").prepend("/path2").to_str).to eq("/path2:/path1")
      expect(klass.new("/path1").prepend("/path1").to_str).to eq("/path1")
    end
  end

  describe "#append" do
    specify(:aggregate_failures) do
      expect(klass.new("/path1").append("/path2").to_str).to eq("/path1:/path2")
      expect(klass.new("/path1").append("/path1").to_str).to eq("/path1")
    end
  end

  describe "#insert" do
    specify(:aggregate_failures) do
      expect(klass.new("/path1").insert(0, "/path2").to_str).to eq("/path2:/path1")
      expect(klass.new("/path1").insert(0, "/path2", "/path3")).to eq("/path2:/path3:/path1")
    end
  end

  describe "#==" do
    it "always returns false when comparing against something which does not respond to `#to_ary` or `#to_str`" do
      expect(klass.new).not_to eq Object.new
    end
  end

  describe "#include?" do
    it "returns true if a path is included", :aggregate_failures do
      path = klass.new("/path1", "/path2")
      expect(path).to include("/path1")
      expect(path).to include("/path2")
      expect(klass.new("/path1", "/path2")).not_to include("/path1:")
    end

    it "returns false if a path is not included" do
      expect(klass.new("/path1")).not_to include("/path2")
    end
  end

  describe "#each" do
    it "loops through each path" do
      enum = klass.new("/path1", "/path2").each

      expect(enum.next).to eq("/path1")
      expect(enum.next).to eq("/path2")
    end
  end

  describe "#select" do
    it "returns an object of the same class instead of an Array" do
      expect(klass.new.select { true }).to be_a(klass)
    end
  end

  describe "#reject" do
    it "returns an object of the same class instead of an Array" do
      expect(klass.new.reject { true }).to be_a(klass)
    end
  end

  describe "#existing" do
    it "returns a new PATH without non-existent paths", :aggregate_failures do
      allow(File).to receive(:directory?).with("/path1").and_return(true)
      allow(File).to receive(:directory?).with("/path2").and_return(false)

      path = klass.new("/path1", "/path2")
      existing = path.existing
      expect(existing).not_to be_nil
      expect(existing&.to_ary).to eq(["/path1"])
      expect(path.to_ary).to eq(["/path1", "/path2"])
    end

    it "returns nil instead of an empty #{PATH}" do
      expect(klass.new.existing).to be_nil
    end
  end
end
