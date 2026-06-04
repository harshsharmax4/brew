# typed: true
# frozen_string_literal: true

require "diagnostic"

RSpec.describe Homebrew::EnvConfig do
  subject(:env_config) { klass }

  let(:klass) { Homebrew::EnvConfig }

  describe "ENVS" do
    it "sorts alphabetically" do
      expect(Homebrew::EnvConfig::ENVS.keys).to eql(Homebrew::EnvConfig::ENVS.keys.sort)
    end
  end

  describe ".env_method_name" do
    it "generates method names" do
      expect(env_config.env_method_name("HOMEBREW_FOO", {})).to eql("foo")
    end

    it "generates boolean method names" do
      expect(env_config.env_method_name("HOMEBREW_BAR", boolean: true)).to eql("bar?")
    end
  end

  describe ".artifact_domain" do
    it "returns value if set" do
      ENV["HOMEBREW_ARTIFACT_DOMAIN"] = "https://brew.sh"
      expect(env_config.artifact_domain).to eql("https://brew.sh")
    end

    it "returns nil if empty" do
      ENV["HOMEBREW_ARTIFACT_DOMAIN"] = ""
      expect(env_config.artifact_domain).to be_nil
    end
  end

  describe ".cleanup_periodic_full_days" do
    it "returns value if set" do
      ENV["HOMEBREW_CLEANUP_PERIODIC_FULL_DAYS"] = "360"
      expect(env_config.cleanup_periodic_full_days).to eql("360")
    end

    it "returns default if unset" do
      ENV["HOMEBREW_CLEANUP_PERIODIC_FULL_DAYS"] = nil
      expect(env_config.cleanup_periodic_full_days).to eql("30")
    end
  end

  describe ".bat?" do
    it "returns true if set" do
      ENV["HOMEBREW_BAT"] = "1"
      expect(env_config.bat?).to be(true)
    end

    it "returns false if unset" do
      ENV["HOMEBREW_BAT"] = nil
      expect(env_config.bat?).to be(false)
    end

    it "returns false if set to a falsey value" do
      ENV["HOMEBREW_BAT"] = "0"
      expect(env_config.bat?).to be(false)
    end
  end

  describe ".ask?" do
    before do
      ENV["HOMEBREW_ASK"] = nil
      ENV["HOMEBREW_NO_ASK"] = nil
    end

    it "returns false if HOMEBREW_NO_ASK is set" do
      ENV["HOMEBREW_ASK"] = "1"
      ENV["HOMEBREW_NO_ASK"] = "1"
      expect(env_config.ask?).to be(false)
    end
  end

  describe ".color?" do
    before do
      ENV["HOMEBREW_COLOR"] = nil
      ENV["HOMEBREW_NO_COLOR"] = nil
    end

    it "returns false if HOMEBREW_NO_COLOR is set" do
      ENV["HOMEBREW_COLOR"] = "1"
      ENV["HOMEBREW_NO_COLOR"] = "1"
      expect(env_config.color?).to be(false)
    end
  end

  describe ".make_jobs" do
    it "returns value if positive" do
      ENV["HOMEBREW_MAKE_JOBS"] = "4"
      expect(env_config.make_jobs).to eql("4")
    end

    it "returns default if negative" do
      ENV["HOMEBREW_MAKE_JOBS"] = "-1"
      expect(Hardware::CPU).to receive(:cores).and_return(16)
      expect(env_config.make_jobs).to eql("16")
    end
  end

  describe ".cask_opts_binaries?" do
    before do
      ENV["HOMEBREW_CASK_OPTS"] = nil
      ENV["HOMEBREW_CASK_OPTS_BINARIES"] = nil
    end

    it "returns false if HOMEBREW_CASK_OPTS_BINARIES is set to a falsey value" do
      ENV["HOMEBREW_CASK_OPTS_BINARIES"] = "0"
      expect(env_config.cask_opts_binaries?).to be(false)
    end
  end

  describe ".cask_opts_require_sha?" do
    before do
      ENV["HOMEBREW_CASK_OPTS"] = nil
      ENV["HOMEBREW_CASK_OPTS_REQUIRE_SHA"] = nil
    end

    it "returns true if HOMEBREW_CASK_OPTS_REQUIRE_SHA is set" do
      ENV["HOMEBREW_CASK_OPTS_REQUIRE_SHA"] = "1"
      expect(env_config.cask_opts_require_sha?).to be(true)
    end
  end

  describe ".bundle_describe?" do
    it "returns false if HOMEBREW_BUNDLE_NO_DESCRIBE is set" do
      with_env(HOMEBREW_BUNDLE_DESCRIBE: "1", HOMEBREW_BUNDLE_NO_DESCRIBE: "1") do
        expect(env_config.bundle_describe?).to be(false)
      end
    end
  end

  describe ".bundle_jobs" do
    it "returns nil if HOMEBREW_BUNDLE_NO_JOBS is set" do
      with_env(HOMEBREW_BUNDLE_JOBS: "auto", HOMEBREW_BUNDLE_NO_JOBS: "1") do
        expect(env_config.bundle_jobs).to be_nil
      end
    end
  end

  describe ".bundle_no_secrets?" do
    it "returns false if HOMEBREW_BUNDLE_SECRETS is set" do
      with_env(HOMEBREW_BUNDLE_NO_SECRETS: "1", HOMEBREW_BUNDLE_SECRETS: "1") do
        expect(env_config.bundle_no_secrets?).to be(false)
      end
    end
  end

  describe ".forbid_packages_from_paths?" do
    around do |example|
      with_env(HOMEBREW_TESTS: ENV.fetch("HOMEBREW_TESTS", nil)) { example.run }
    end

    before do
      ENV["HOMEBREW_FORBID_PACKAGES_FROM_PATHS"] = nil
      ENV["HOMEBREW_DEVELOPER"] = nil
      ENV["HOMEBREW_TESTS"] = nil
    end

    it "returns true if HOMEBREW_FORBID_PACKAGES_FROM_PATHS is set" do
      ENV["HOMEBREW_FORBID_PACKAGES_FROM_PATHS"] = "1"
      expect(env_config.forbid_packages_from_paths?).to be(true)
    end

    it "returns true if HOMEBREW_DEVELOPER is not set" do
      ENV["HOMEBREW_DEVELOPER"] = nil
      expect(env_config.forbid_packages_from_paths?).to be(true)
    end

    it "returns false if HOMEBREW_DEVELOPER is set and HOMEBREW_FORBID_PACKAGES_FROM_PATHS is not set" do
      ENV["HOMEBREW_DEVELOPER"] = "1"
      ENV["HOMEBREW_FORBID_PACKAGES_FROM_PATHS"] = nil
      expect(env_config.forbid_packages_from_paths?).to be(false)
    end

    it "returns true if both HOMEBREW_DEVELOPER and HOMEBREW_FORBID_PACKAGES_FROM_PATHS are set" do
      ENV["HOMEBREW_DEVELOPER"] = "1"
      ENV["HOMEBREW_FORBID_PACKAGES_FROM_PATHS"] = "1"
      expect(env_config.forbid_packages_from_paths?).to be(true)
    end
  end

  describe ".upgrade_auto_updates_casks?" do
    around do |example|
      with_env(
        HOMEBREW_DEVELOPER:                     nil,
        HOMEBREW_UPGRADE_AUTO_UPDATES_CASKS:    nil,
        HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS: nil,
      ) { example.run }
    end

    it "does not infer a developer default" do
      ENV["HOMEBREW_DEVELOPER"] = "1"
      expect(env_config.upgrade_auto_updates_casks?).to be(false)
    end

    it "returns true if set to a falsey value" do
      ENV["HOMEBREW_UPGRADE_AUTO_UPDATES_CASKS"] = "0"
      expect(env_config.upgrade_auto_updates_casks?).to be(true)
    end

    it "returns false if HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS is set" do
      ENV["HOMEBREW_UPGRADE_AUTO_UPDATES_CASKS"] = "1"
      ENV["HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS"] = "1"
      expect(env_config.upgrade_auto_updates_casks?).to be(false)
    end
  end

  describe ".sandbox_linux?" do
    around do |example|
      with_env(
        HOMEBREW_DEVELOPER:        nil,
        HOMEBREW_NO_SANDBOX_LINUX: nil,
        HOMEBREW_SANDBOX_LINUX:    nil,
      ) { example.run }
    end

    it "returns true if HOMEBREW_SANDBOX_LINUX is set" do
      ENV["HOMEBREW_SANDBOX_LINUX"] = "1"
      expect(env_config.sandbox_linux?).to be(true)
    end

    it "does not infer a developer default" do
      ENV["HOMEBREW_DEVELOPER"] = "1"
      expect(env_config.sandbox_linux?).to be(false)
    end

    it "returns true if HOMEBREW_SANDBOX_LINUX is set to a falsey value with HOMEBREW_DEVELOPER" do
      ENV["HOMEBREW_DEVELOPER"] = "1"
      ENV["HOMEBREW_SANDBOX_LINUX"] = "0"
      expect(env_config.sandbox_linux?).to be(true)
    end

    it "returns false if HOMEBREW_NO_SANDBOX_LINUX is set" do
      ENV["HOMEBREW_NO_SANDBOX_LINUX"] = "1"
      ENV["HOMEBREW_SANDBOX_LINUX"] = "1"
      expect(env_config.sandbox_linux?).to be(false)
    end

    it "returns false if HOMEBREW_DEVELOPER and HOMEBREW_NO_SANDBOX_LINUX are set" do
      ENV["HOMEBREW_DEVELOPER"] = "1"
      ENV["HOMEBREW_NO_SANDBOX_LINUX"] = "1"
      expect(env_config.sandbox_linux?).to be(false)
    end
  end

  describe ".require_tap_trust?" do
    around do |example|
      with_env(
        HOMEBREW_REQUIRE_TAP_TRUST:    nil,
        HOMEBREW_NO_REQUIRE_TAP_TRUST: nil,
      ) { example.run }
    end

    it "returns false if HOMEBREW_NO_REQUIRE_TAP_TRUST is set" do
      ENV["HOMEBREW_REQUIRE_TAP_TRUST"] = "1"
      ENV["HOMEBREW_NO_REQUIRE_TAP_TRUST"] = "1"
      expect(env_config.require_tap_trust?).to be(false)
    end
  end

  describe ".verify_attestations?" do
    around do |example|
      with_env(
        HOMEBREW_VERIFY_ATTESTATIONS:    nil,
        HOMEBREW_NO_VERIFY_ATTESTATIONS: nil,
      ) { example.run }
    end

    it "returns false if HOMEBREW_NO_VERIFY_ATTESTATIONS is set" do
      ENV["HOMEBREW_VERIFY_ATTESTATIONS"] = "1"
      ENV["HOMEBREW_NO_VERIFY_ATTESTATIONS"] = "1"
      expect(env_config.verify_attestations?).to be(false)
    end
  end

  describe ".no_sandbox_cask?" do
    it "returns true if HOMEBREW_NO_SANDBOX_CASK is set" do
      ENV["HOMEBREW_NO_SANDBOX_CASK"] = "1"
      expect(env_config.no_sandbox_cask?).to be(true)
    ensure
      ENV["HOMEBREW_NO_SANDBOX_CASK"] = nil
    end
  end

  describe ".no_sandbox_linux?" do
    it "returns true if set to a falsey value" do
      ENV["HOMEBREW_NO_SANDBOX_LINUX"] = "0"
      expect(env_config.no_sandbox_linux?).to be(true)
    ensure
      ENV["HOMEBREW_NO_SANDBOX_LINUX"] = nil
    end
  end

  describe ".eval_all?" do
    before do
      ENV["HOMEBREW_EVAL_ALL"] = nil
      ENV["HOMEBREW_REQUIRE_TAP_TRUST"] = nil
      ENV["HOMEBREW_NO_REQUIRE_TAP_TRUST"] = nil
      env_config.instance_variable_set(:@eval_all_deprecation_warned, nil)
    end

    it "returns false if HOMEBREW_REQUIRE_TAP_TRUST is set" do
      ENV["HOMEBREW_REQUIRE_TAP_TRUST"] = "1"

      expect(env_config.eval_all?).to be(false)
    end

    it "returns false if HOMEBREW_NO_REQUIRE_TAP_TRUST is set" do
      ENV["HOMEBREW_NO_REQUIRE_TAP_TRUST"] = "1"

      expect(env_config.eval_all?).to be(false)
    end

    it "warns if HOMEBREW_EVAL_ALL is set" do
      ENV["HOMEBREW_EVAL_ALL"] = "1"

      expect { expect(env_config.eval_all?).to be(true) }
        .to output(/HOMEBREW_EVAL_ALL.*deprecated.*HOMEBREW_REQUIRE_TAP_TRUST.*HOMEBREW_NO_REQUIRE_TAP_TRUST/m)
        .to_stderr
    end

    it "warns only once if HOMEBREW_EVAL_ALL is set and queried repeatedly" do
      ENV["HOMEBREW_EVAL_ALL"] = "1"

      env_config.eval_all?
      expect { env_config.eval_all? }.not_to output.to_stderr
    end
  end

  describe ".tap_trust_configured?" do
    before do
      ENV["HOMEBREW_REQUIRE_TAP_TRUST"] = nil
      ENV["HOMEBREW_NO_REQUIRE_TAP_TRUST"] = nil
    end

    it "returns true if HOMEBREW_REQUIRE_TAP_TRUST is set" do
      ENV["HOMEBREW_REQUIRE_TAP_TRUST"] = "1"

      expect(env_config.tap_trust_configured?).to be(true)
      expect(env_config.require_tap_trust?).to be(true)
    end

    it "returns true if HOMEBREW_NO_REQUIRE_TAP_TRUST is set" do
      ENV["HOMEBREW_NO_REQUIRE_TAP_TRUST"] = "1"

      expect(env_config.tap_trust_configured?).to be(true)
      expect(env_config.no_require_tap_trust?).to be(true)
    end
  end

  describe ".use_internal_api?" do
    around do |example|
      with_env(
        HOMEBREW_USE_INTERNAL_API:    nil,
        HOMEBREW_NO_INSTALL_FROM_API: nil,
      ) { example.run }
    end

    it "returns true if HOMEBREW_USE_INTERNAL_API is set" do
      ENV["HOMEBREW_USE_INTERNAL_API"] = "1"
      expect(env_config.use_internal_api?).to be(true)
    end

    it "returns false if HOMEBREW_USE_INTERNAL_API is not set" do
      ENV["HOMEBREW_USE_INTERNAL_API"] = nil
      expect(env_config.use_internal_api?).to be(false)
    end

    it "returns true if HOMEBREW_USE_INTERNAL_API is set to a falsey value" do
      ENV["HOMEBREW_USE_INTERNAL_API"] = "0"
      expect(env_config.use_internal_api?).to be(true)
    end

    it "returns false if HOMEBREW_NO_INSTALL_FROM_API is set" do
      ENV["HOMEBREW_USE_INTERNAL_API"] = "1"
      ENV["HOMEBREW_NO_INSTALL_FROM_API"] = "1"
      expect(env_config.use_internal_api?).to be(false)
    end
  end
end
