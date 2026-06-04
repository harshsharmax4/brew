# typed: strict
# frozen_string_literal: true

require "settings"

RSpec.describe Homebrew::SimulateSystem do
  sig { returns(T.class_of(Homebrew::SimulateSystem)) }
  let(:klass) { Homebrew::SimulateSystem }

  after do
    klass.clear
  end

  describe "::simulating_or_running_on_macos?" do
    it "returns true on macOS", :needs_macos do
      klass.clear
      expect(klass.simulating_or_running_on_macos?).to be true
    end

    it "returns false on Linux", :needs_linux do
      klass.clear
      expect(klass.simulating_or_running_on_macos?).to be false
    end

    it "returns false on macOS when simulating Linux", :needs_macos do
      klass.clear
      klass.os = :linux
      expect(klass.simulating_or_running_on_macos?).to be false
    end

    it "returns true on Linux when simulating a generic macOS version", :needs_linux do
      klass.clear
      klass.os = :macos
      expect(klass.simulating_or_running_on_macos?).to be true
    end

    it "returns true on Linux when simulating a specific macOS version", :needs_linux do
      klass.clear
      klass.os = :monterey
      expect(klass.simulating_or_running_on_macos?).to be true
    end

    it "returns true on Linux with HOMEBREW_SIMULATE_MACOS_ON_LINUX", :needs_linux do
      klass.clear
      ENV["HOMEBREW_SIMULATE_MACOS_ON_LINUX"] = "1"
      expect(klass.simulating_or_running_on_macos?).to be true
    end
  end

  describe "::simulating_or_running_on_linux?" do
    it "returns true on Linux", :needs_linux do
      klass.clear
      expect(klass.simulating_or_running_on_linux?).to be true
    end

    it "returns false on macOS", :needs_macos do
      klass.clear
      expect(klass.simulating_or_running_on_linux?).to be false
    end

    it "returns true on macOS when simulating Linux", :needs_macos do
      klass.clear
      klass.os = :linux
      expect(klass.simulating_or_running_on_linux?).to be true
    end

    it "returns false on Linux when simulating a generic macOS version", :needs_linux do
      klass.clear
      klass.os = :macos
      expect(klass.simulating_or_running_on_linux?).to be false
    end

    it "returns false on Linux when simulating a specific macOS version", :needs_linux do
      klass.clear
      klass.os = :monterey
      expect(klass.simulating_or_running_on_linux?).to be false
    end

    it "returns false on Linux with HOMEBREW_SIMULATE_MACOS_ON_LINUX", :needs_linux do
      klass.clear
      ENV["HOMEBREW_SIMULATE_MACOS_ON_LINUX"] = "1"
      expect(klass.simulating_or_running_on_linux?).to be false
    end
  end

  describe "::current_arch" do
    it "returns the current architecture" do
      klass.clear
      expect(klass.current_arch).to eq Hardware::CPU.type
    end

    it "returns the simulated architecture" do
      klass.clear
      simulated_arch = if Hardware::CPU.arm?
        :intel
      else
        :arm
      end
      klass.arch = simulated_arch
      expect(klass.current_arch).to eq simulated_arch
    end
  end

  describe "::current_os" do
    it "returns the current macOS version on macOS", :needs_macos do
      klass.clear
      expect(klass.current_os).to eq MacOS.version.to_sym
    end

    it "returns `:linux` on Linux", :needs_linux do
      klass.clear
      expect(klass.current_os).to eq :linux
    end

    it "returns `:linux` when simulating Linux on macOS", :needs_macos do
      klass.clear
      klass.os = :linux
      expect(klass.current_os).to eq :linux
    end

    it "returns `:macos` when simulating a generic macOS version on Linux", :needs_linux do
      klass.clear
      klass.os = :macos
      expect(klass.current_os).to eq :macos
    end

    it "returns `:macos` when simulating a specific macOS version on Linux", :needs_linux do
      klass.clear
      klass.os = :monterey
      expect(klass.current_os).to eq :monterey
    end

    it "returns the current macOS version on macOS with HOMEBREW_SIMULATE_MACOS_ON_LINUX", :needs_macos do
      klass.clear
      ENV["HOMEBREW_SIMULATE_MACOS_ON_LINUX"] = "1"
      expect(klass.current_os).to eq MacOS.version.to_sym
    end

    it "returns the newest supported macOS symbol on Linux with HOMEBREW_SIMULATE_MACOS_ON_LINUX", :needs_linux do
      klass.clear
      ENV["HOMEBREW_SIMULATE_MACOS_ON_LINUX"] = "1"
      expect(klass.current_os).to eq MacOSVersion.new(HOMEBREW_MACOS_NEWEST_SUPPORTED).to_sym
    end
  end
end
