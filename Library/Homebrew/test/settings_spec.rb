# typed: true
# frozen_string_literal: true

require "settings"

RSpec.describe Homebrew::Settings do
  let(:klass) { Homebrew::Settings }

  before do
    HOMEBREW_REPOSITORY.cd do
      system "git", "init"
    end
  end

  def setup_setting
    HOMEBREW_REPOSITORY.cd do
      system "git", "config", "--replace-all", "homebrew.foo", "true"
    end
  end

  describe ".read" do
    it "returns the correct value for a setting" do
      setup_setting
      expect(klass.read("foo")).to eq "true"
    end

    it "returns the correct value for a setting as a symbol" do
      setup_setting
      expect(klass.read(:foo)).to eq "true"
    end

    it "returns nil when setting is not set" do
      setup_setting
      expect(klass.read("bar")).to be_nil
    end

    it "runs on a repo without a configuration file" do
      expect { klass.read("foo", repo: HOMEBREW_REPOSITORY/"bar") }.not_to raise_error
    end
  end

  describe ".write" do
    it "writes over an existing value" do
      setup_setting
      klass.write :foo, false
      expect(klass.read("foo")).to eq "false"
    end

    it "writes a new value" do
      setup_setting
      klass.write :bar, "abcde"
      expect(klass.read("bar")).to eq "abcde"
    end

    it "returns if the repo doesn't have a configuration file" do
      expect { klass.write("foo", false, repo: HOMEBREW_REPOSITORY/"bar") }.not_to raise_error
    end
  end

  describe ".delete" do
    it "deletes an existing setting" do
      setup_setting
      klass.delete(:foo)
      expect(klass.read("foo")).to be_nil
    end

    it "deletes a non-existing setting" do
      setup_setting
      expect { klass.delete(:bar) }.not_to raise_error
    end

    it "returns if the repo doesn't have a configuration file" do
      expect { klass.delete("foo", repo: HOMEBREW_REPOSITORY/"bar") }.not_to raise_error
    end
  end
end
