# typed: strict
# frozen_string_literal: true

require "tap"
require "trust"

RSpec.describe Homebrew::Trust do
  it "lets HOMEBREW_NO_REQUIRE_TAP_TRUST override HOMEBREW_REQUIRE_TAP_TRUST" do
    with_env(HOMEBREW_REQUIRE_TAP_TRUST: "1", HOMEBREW_NO_REQUIRE_TAP_TRUST: "1") do
      expect(Homebrew::EnvConfig.require_tap_trust?).to be(false)
    end
  end

  it "trusts third-party taps" do
    tap = Tap.fetch("thirdparty", "foo")

    expect(Homebrew::Trust.trusted_tap?(tap)).to be(false)

    Homebrew::Trust.trust!(:tap, "thirdparty/foo")

    expect(Homebrew::Trust.trusted_tap?(tap)).to be(true)
  ensure
    Homebrew::Trust.clear!(:tap)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "ignores a trust file with a non-object JSON root" do
    trust_file = T.let(nil, T.nilable(Pathname))
    trust_file = Homebrew::Trust.trust_file
    trust_file.dirname.mkpath
    trust_file.write("[]")

    expect(Homebrew::Trust.trusted?(:tap, "thirdparty/foo")).to be(false)
  ensure
    trust_file.unlink if trust_file&.exist?
  end

  it "untrusts third-party taps" do
    Homebrew::Trust.trust!(:tap, "thirdparty/foo")

    expect(Homebrew::Trust.untrust!(:tap, "thirdparty/foo")).to be(true)
    expect(Homebrew::Trust.trusted?(:tap, "thirdparty/foo")).to be(false)
  ensure
    Homebrew::Trust.clear!(:tap)
  end

  it "trusts fully-qualified formulae and casks" do
    tap = Tap.fetch("thirdparty", "foo")
    tap.formula_dir.mkpath
    tap.cask_dir.mkpath
    (tap.formula_dir/"bar.rb").write("class Bar < Formula; end\n")
    (tap.cask_dir/"baz.rb").write("cask 'baz'\n")

    Homebrew::Trust.trust_fully_qualified_items!(["thirdparty/foo/bar", "thirdparty/foo/baz"])

    expect(Homebrew::Trust.trusted?(:formula, "thirdparty/foo/bar")).to be(true)
    expect(Homebrew::Trust.trusted?(:cask, "thirdparty/foo/baz")).to be(true)
  ensure
    Homebrew::Trust.clear!(:formula)
    Homebrew::Trust.clear!(:cask)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "does not trust missing fully-qualified formulae or casks" do
    Tap.fetch("thirdparty", "foo")

    Homebrew::Trust.trust_fully_qualified_items!(["thirdparty/foo/bar"], type: :formula)
    Homebrew::Trust.trust_fully_qualified_items!(["thirdparty/foo/baz"], type: :cask)

    expect(Homebrew::Trust.trusted?(:formula, "thirdparty/foo/bar")).to be(false)
    expect(Homebrew::Trust.trusted?(:cask, "thirdparty/foo/baz")).to be(false)
  ensure
    Homebrew::Trust.clear!(:formula)
    Homebrew::Trust.clear!(:cask)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "does not report taps with trusted entries as wholly untrusted" do
    allow(Homebrew::Trust).to receive(:untrusted_taps)
      .and_return([instance_double(Tap, name: "thirdparty/foo")])
    Homebrew::Trust.trust!(:formula, "thirdparty/foo/bar")

    expect(Homebrew::Trust.wholly_untrusted_taps).to be_empty
  ensure
    Homebrew::Trust.clear!(:formula)
  end

  it "writes the trust store with user-only permissions" do
    Homebrew::Trust.trust!(:tap, "thirdparty/foo")

    trust_file = Homebrew::Trust.trust_file
    expect(trust_file.stat.mode & 0777).to eq(0600)
  ensure
    Homebrew::Trust.clear!(:tap)
  end

  it "allows third-party taps by default" do
    Homebrew::Trust.clear!(:tap)
    tap = Tap.fetch("thirdparty", "foo")
    formula_path = tap.formula_dir/"default-trust.rb"
    formula_path.dirname.mkpath

    expect { Homebrew::Trust.require_trusted_formula!("default-trust", formula_path) }
      .not_to output.to_stderr

    expect(Homebrew::Trust.trusted?(:tap, "thirdparty/foo")).to be(false)
  ensure
    Homebrew::Trust.clear!(:tap)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "does not store default trust when checking files" do
    tap = Tap.fetch("thirdparty", "foo")
    formula_path = tap.formula_dir/"default-trust.rb"
    formula_path.dirname.mkpath

    expect { expect(Homebrew::Trust.trusted_formula_file?(formula_path)).to be(true) }
      .not_to output.to_stderr

    expect(Homebrew::Trust.trusted?(:tap, "thirdparty/foo")).to be(false)
  ensure
    Homebrew::Trust.clear!(:tap)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "does not trust untrusted files when trust checks are enabled" do
    tap = Tap.fetch("thirdparty", "foo")
    formula_path = tap.formula_dir/"default-trust.rb"
    formula_path.dirname.mkpath

    with_env(HOMEBREW_REQUIRE_TAP_TRUST: "1") do
      expect(Homebrew::Trust.trusted_formula_file?(formula_path)).to be(false)
    end
  ensure
    Homebrew::Trust.clear!(:tap)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "allows explicitly named formula files when trust checks are enabled" do
    old_argv = ARGV.dup
    tap = Tap.fetch("thirdparty", "foo")
    formula_path = tap.formula_dir/"default-trust.rb"
    formula_path.dirname.mkpath

    with_env(HOMEBREW_REQUIRE_TAP_TRUST: "1") do
      ARGV.replace(["thirdparty/foo/default-trust"])
      expect(Homebrew::Trust.trusted_formula_file?(formula_path)).to be(true)
    end

    expect(Homebrew::Trust.trusted?(:formula, "thirdparty/foo/default-trust")).to be(false)
  ensure
    ARGV.replace(old_argv) if old_argv
    Homebrew::Trust.clear!(:tap)
    Homebrew::Trust.clear!(:formula)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "allows files from explicitly named taps when trust checks are enabled" do
    old_argv = ARGV.dup
    tap = Tap.fetch("thirdparty", "foo")
    cask_path = tap.cask_dir/"default-trust.rb"
    cask_path.dirname.mkpath

    with_env(HOMEBREW_REQUIRE_TAP_TRUST: "1") do
      ARGV.replace(["--tap", "thirdparty/foo"])
      expect(Homebrew::Trust.trusted_cask_file?(cask_path)).to be(true)
    end

    expect(Homebrew::Trust.trusted?(:tap, "thirdparty/foo")).to be(false)
    expect(Homebrew::Trust.trusted?(:cask, "thirdparty/foo/default-trust")).to be(false)
  ensure
    ARGV.replace(old_argv) if old_argv
    Homebrew::Trust.clear!(:tap)
    Homebrew::Trust.clear!(:cask)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "does not allow explicitly named command files when trust checks are enabled" do
    old_argv = ARGV.dup
    tap = Tap.fetch("thirdparty", "foo")
    command_path = tap.path/"cmd/brew-default-trust.rb"
    command_path.dirname.mkpath

    with_env(HOMEBREW_REQUIRE_TAP_TRUST: "1") do
      ARGV.replace(["thirdparty/foo/default-trust"])
      expect(Homebrew::Trust.trusted_command_files([command_path])).to eq([])
    end
  ensure
    ARGV.replace(old_argv) if old_argv
    Homebrew::Trust.clear!(:command)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "does not trust untrusted command files when trust checks are enabled" do
    tap = Tap.fetch("thirdparty", "foo")
    command_path = tap.path/"cmd/brew-default-trust.rb"
    command_path.dirname.mkpath

    with_env(HOMEBREW_REQUIRE_TAP_TRUST: "1") do
      expect { expect(Homebrew::Trust.trusted_command_files([command_path])).to eq([]) }
        .to output(%r{Skipping thirdparty/foo because it is not trusted}).to_stderr
    end
  ensure
    Homebrew::Trust.clear!(:tap)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end

  it "does not store default trust when trust checks are disabled" do
    tap = Tap.fetch("thirdparty", "foo")
    formula_path = tap.formula_dir/"default-trust.rb"
    formula_path.dirname.mkpath

    with_env(HOMEBREW_NO_REQUIRE_TAP_TRUST: "1") do
      expect { Homebrew::Trust.require_trusted_formula!("default-trust", formula_path) }
        .not_to output.to_stderr
    end

    expect(Homebrew::Trust.trusted?(:tap, "thirdparty/foo")).to be(false)
  ensure
    Homebrew::Trust.clear!(:tap)
    FileUtils.rm_rf HOMEBREW_TAP_DIRECTORY/"thirdparty"
  end
end
