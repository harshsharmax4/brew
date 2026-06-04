# typed: true
# frozen_string_literal: true

require "cmd/outdated"
require "cmd/shared_examples/args_parse"

RSpec.describe Homebrew::Cmd::Outdated do
  let(:klass) { Homebrew::Cmd::Outdated }

  it_behaves_like "parseable arguments"

  def install_formula_version(name, version, linked: false)
    keg_path = HOMEBREW_CELLAR/name/version
    keg_path.mkpath
    tab = Tab.empty
    tab.tabfile = keg_path/AbstractTab::FILENAME
    tab.write
    return unless linked

    (HOMEBREW_LINKED_KEGS/name).parent.mkpath
    FileUtils.ln_s(keg_path, HOMEBREW_LINKED_KEGS/name)
  end

  def write_formula(name, content)
    Formulary.find_formula_in_tap(name, CoreTap.instance).tap do |path|
      path.dirname.mkpath
      path.write <<~RUBY
        class #{Formulary.class_s(name)} < Formula
        #{content.gsub(/^(?!$)/, "  ")}
        end
      RUBY
      CoreTap.instance.clear_cache
    end
  end

  it "requires one named argument with --minimum-version" do
    expect { klass.new(["--minimum-version=1.2.3"]).run }
      .to raise_error(UsageError, /`--minimum-version` requires exactly one formula or cask argument/)
  end

  it "rejects multiple named arguments with --minimum-version" do
    expect { klass.new(["foo", "bar", "--minimum-version=1.2.3"]).run }
      .to raise_error(UsageError, /`--minimum-version` requires exactly one formula or cask argument/)
  end

  it "excludes non-outdated auto-updating casks without --greedy-auto-updates", :cask do
    cask = Cask::CaskLoader.load(cask_path("auto-updates"))
    cmd = klass.new([])

    expect(cask).to receive(:outdated?)
      .with(greedy: false, greedy_latest: false, greedy_auto_updates: false)
      .and_return(false)
    expect(cmd.send(:select_outdated, [cask])).to be_empty
  end

  it "checks auto-updating casks with --greedy-auto-updates", :cask do
    cask = Cask::CaskLoader.load(cask_path("auto-updates"))
    cmd = klass.new(["--greedy-auto-updates"])

    expect(cask).to receive(:outdated?)
      .with(greedy: false, greedy_latest: false, greedy_auto_updates: true)
      .and_return(true)
    expect(cmd.send(:select_outdated, [cask])).to eq([cask])
  end

  it "outputs JSON for outdated formulae and casks", :cask, :integration_test do
    setup_test_formula "testball"
    (HOMEBREW_CELLAR/"testball/0.0.1/foo").mkpath
    InstallHelper.stub_cask_installation(Cask::CaskLoader.load(cask_path("outdated/local-caffeine")))

    expected_json = JSON.pretty_generate({
      formulae: [{
        name:               "testball",
        installed_versions: ["0.0.1"],
        current_version:    "0.1",
        pinned:             false,
        pinned_version:     nil,
      }],
      casks:    [{
        name:               "local-caffeine",
        installed_versions: ["1.2.2"],
        current_version:    "1.2.3",
        pinned:             false,
        pinned_version:     nil,
      }],
    })

    expect { brew "outdated", "--json=v2" }
      .to output("#{expected_json}\n").to_stdout
      .and be_a_success
  end

  it "reports a formula installed below the minimum version" do
    write_formula "minimum-version-formula", <<~RUBY
      url "https://brew.sh/minimum-version-formula-1.2.3"
    RUBY
    install_formula_version "minimum-version-formula", "1.2.2"

    expect { klass.new(["minimum-version-formula", "--min-version=1.2.3"]).run }
      .to output("minimum-version-formula\n").to_stdout
    expect(Homebrew).to have_failed
  end

  it "does not report a formula installed at --minimum-version" do
    write_formula "minimum-version-formula", <<~RUBY
      url "https://brew.sh/minimum-version-formula-1.2.3"
    RUBY
    install_formula_version "minimum-version-formula", "1.2.3", linked: true

    expect { klass.new(["minimum-version-formula", "--minimum-version=1.2.3"]).run }
      .not_to output.to_stdout
  end

  it "reports a cask installed below --minimum-version", :cask do
    InstallHelper.stub_cask_installation(Cask::CaskLoader.load(cask_path("outdated/local-caffeine")))

    expect { klass.new(["--cask", "local-caffeine", "--minimum-version=1.2.3"]).run }
      .to output("local-caffeine\n").to_stdout
    expect(Homebrew).to have_failed
  end

  it "does not report a cask installed at --minimum-version", :cask do
    InstallHelper.stub_cask_installation(Cask::CaskLoader.load(cask_path("local-caffeine")))

    expect { klass.new(["--cask", "local-caffeine", "--minimum-version=1.2.3"]).run }
      .not_to output.to_stdout
  end

  it "raises UsageError for an invalid cask --minimum-version", :cask do
    InstallHelper.stub_cask_installation(Cask::CaskLoader.load(cask_path("local-caffeine")))

    expect { klass.new(["--cask", "local-caffeine", "--minimum-version=1/2"]).run }
      .to raise_error(UsageError, %r{invalid `--minimum-version`: 1/2})
  end

  it "does not report an uninstalled formula with --minimum-version" do
    write_formula "minimum-version-formula", <<~RUBY
      url "https://brew.sh/minimum-version-formula-1.2.3"
    RUBY

    expect { klass.new(["minimum-version-formula", "--minimum-version=1.2.3"]).run }
      .not_to output.to_stdout
  end

  it "outputs JSON for a formula installed below --minimum-version" do
    write_formula "minimum-version-formula", <<~RUBY
      url "https://brew.sh/minimum-version-formula-1.2.3"
    RUBY
    install_formula_version "minimum-version-formula", "1.2.2"

    expected_json = JSON.pretty_generate({
      formulae: [{
        name:               "minimum-version-formula",
        installed_versions: ["1.2.2"],
        current_version:    "1.2.3",
        pinned:             false,
        pinned_version:     nil,
      }],
      casks:    [],
    })

    expect { klass.new(["minimum-version-formula", "--minimum-version=1.2.3", "--json=v2"]).run }
      .to output("#{expected_json}\n").to_stdout
    expect(Homebrew).to have_failed
  end

  it "outputs JSON for a cask installed below --minimum-version", :cask do
    InstallHelper.stub_cask_installation(Cask::CaskLoader.load(cask_path("outdated/local-caffeine")))

    expected_json = JSON.pretty_generate({
      formulae: [],
      casks:    [{
        name:               "local-caffeine",
        installed_versions: ["1.2.2"],
        current_version:    "1.2.3",
        pinned:             false,
        pinned_version:     nil,
      }],
    })

    expect { klass.new(["--cask", "local-caffeine", "--minimum-version=1.2.3", "--json=v2"]).run }
      .to output("#{expected_json}\n").to_stdout
    expect(Homebrew).to have_failed
  end
end
