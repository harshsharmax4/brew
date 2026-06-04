# typed: false
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "cmd/upgrade"
require "cmd/shared_examples/reinstall_pkgconf_if_needed"

RSpec.describe Homebrew::Cmd::UpgradeCmd do
  let(:klass) { Homebrew::Cmd::UpgradeCmd }

  include FileUtils

  it_behaves_like "parseable arguments"

  it "trusts fully-qualified named items before resolving them" do
    cmd = klass.new(["thirdparty/foo/bar"])
    allow(cmd.args.named).to receive(:present?).and_return(true)
    allow(cmd.args.named).to receive(:to_formulae_and_casks_and_unavailable)
      .with(method: :resolve)
      .and_return([])
    allow(cmd).to receive_messages(upgrade_outdated_formulae!: true, upgrade_outdated_casks!: false)

    expect(Homebrew::Trust).to receive(:trust_fully_qualified_items!)
      .with(cmd.args.named, type: nil)

    cmd.run
  end

  def install_formula_version(name, version, optlinked: false)
    keg_path = HOMEBREW_CELLAR/name/version
    keg_path.mkpath
    tab = Tab.empty
    tab.tabfile = keg_path/AbstractTab::FILENAME
    tab.write
    return unless optlinked

    (HOMEBREW_PREFIX/"opt").mkpath
    FileUtils.ln_s(keg_path, HOMEBREW_PREFIX/"opt/#{name}")
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

  it "upgrades a Formula and Cask", :cask, :integration_test do
    formula_name = "testball_bottle"
    formula_rack = HOMEBREW_CELLAR/formula_name

    setup_test_formula formula_name
    mktmpdir do |dir|
      (dir/"local-upgrade-test.rb").write <<~RUBY
        cask "local-upgrade-test" do
          version "1.0"
          sha256 :no_check
          url "file://#{TEST_FIXTURE_DIR}/cask/caffeine.zip"
          stage_only true
        end
      RUBY
      (CoreCaskTap.instance.cask_dir/"local-upgrade-test.rb").write <<~RUBY
        cask "local-upgrade-test" do
          version "2.0"
          sha256 :no_check
          url "file://#{TEST_FIXTURE_DIR}/cask/caffeine.zip"
          stage_only true
        end
      RUBY
      CoreCaskTap.instance.clear_cache
      InstallHelper.stub_cask_installation(Cask::CaskLoader.load(dir/"local-upgrade-test.rb"))

      (formula_rack/"0.0.1/foo").mkpath

      expect do
        brew "upgrade", formula_name, "local-upgrade-test"
      end.to be_a_success

      expect(formula_rack/"0.1").to be_a_directory
      expect(formula_rack/"0.0.1").not_to exist
      expect(Cask::CaskLoader.load("local-upgrade-test").installed_version).to eq("2.0")
    end
  end

  # links newer version when upgrade was interrupted
  it "links a newer Formula version when upgrade was interrupted" do
    formula_name = "testball_bottle"
    formula_rack = HOMEBREW_CELLAR/formula_name
    write_formula formula_name, <<~RUBY
      url "file://#{TEST_FIXTURE_DIR}/tarballs/testball-0.1.tbz"
      sha256 TESTBALL_SHA256

      bottle do
        root_url "file://#{TEST_FIXTURE_DIR}/bottles"
        sha256 cellar: :any_skip_relocation, all: "d7b9f4e8bf83608b71fe958a99f19f2e5e68bb2582965d32e41759c24f1aef97"
      end
    RUBY
    install_formula_version formula_name, "0.1"

    expect { klass.new([]).run }.not_to raise_error

    expect(formula_rack/"0.1").to be_a_directory
    expect(HOMEBREW_PREFIX/"opt/#{formula_name}").to be_a_symlink
    expect(HOMEBREW_PREFIX/"var/homebrew/linked/#{formula_name}").to be_a_symlink
  end

  # refuses to upgrade a forbidden formula
  it "refuses to upgrade a forbidden Formula" do
    formula_name = "testball_bottle"
    formula_rack = HOMEBREW_CELLAR/formula_name
    write_formula formula_name, <<~RUBY
      url "https://brew.sh/#{formula_name}-0.1"
    RUBY
    (formula_rack/"0.0.1/foo").mkpath

    with_env("HOMEBREW_FORBIDDEN_FORMULAE" => formula_name) do
      expect { klass.new([formula_name]).run }
        .to not_to_output(%r{#{formula_rack}/0\.1}o).to_stdout
        .and output(/#{formula_name} was forbidden/).to_stderr
    end
    expect(Homebrew).to have_failed
    expect(formula_rack/"0.1").not_to exist
  end

  it "upgrades a named formula installed below the minimum version" do
    write_formula "minimum-version-formula", <<~RUBY
      url "https://brew.sh/minimum-version-formula-1.2.3"
    RUBY
    install_formula_version "minimum-version-formula", "1.2.2", optlinked: true

    expect { klass.new(["minimum-version-formula", "--min-version=1.2.3", "--dry-run"]).run }
      .to output(/minimum-version-formula 1\.2\.2 -> 1\.2\.3/).to_stdout
  end

  it "does not upgrade a named formula installed at --minimum-version" do
    write_formula "minimum-version-formula", <<~RUBY
      url "https://brew.sh/minimum-version-formula-1.2.4"
    RUBY
    install_formula_version "minimum-version-formula", "1.2.3", optlinked: true

    expect { klass.new(["minimum-version-formula", "--minimum-version=1.2.3", "--dry-run"]).run }
      .to not_to_output(/Would upgrade/).to_stdout
      .and output(
        /Not upgrading minimum-version-formula, the installed version is not below the minimum version 1\.2\.3/,
      ).to_stderr
  end

  it "requires one named argument with --minimum-version" do
    expect { klass.new(["--minimum-version=1.2.3"]).run }
      .to raise_error(UsageError, /`--minimum-version` requires exactly one formula or cask argument/)
  end

  it "rejects multiple named arguments with --minimum-version" do
    expect { klass.new(["foo", "bar", "--minimum-version=1.2.3"]).run }
      .to raise_error(UsageError, /`--minimum-version` requires exactly one formula or cask argument/)
  end

  it "upgrades a named cask installed below --minimum-version", :cask do
    InstallHelper.stub_cask_installation(Cask::CaskLoader.load(cask_path("outdated/local-caffeine")))

    expect { klass.new(["--cask", "local-caffeine", "--minimum-version=1.2.3", "--dry-run"]).run }
      .to output(/local-caffeine 1\.2\.2 -> 1\.2\.3/).to_stdout
  end

  it "does not upgrade a named cask installed at --minimum-version", :cask do
    InstallHelper.stub_cask_installation(Cask::CaskLoader.load(cask_path("local-caffeine")))

    expect { klass.new(["--cask", "local-caffeine", "--minimum-version=1.2.3", "--dry-run"]).run }
      .to not_to_output(/Would upgrade/).to_stdout
      .and output(/Not upgrading local-caffeine, the installed version is not below the minimum version 1\.2\.3/)
      .to_stderr
  end

  it "reports unavailable names via ofail and continues upgrading" do
    error = FormulaOrCaskUnavailableError.new("nonexistent")
    formula = instance_double(Formula, full_name: "testball")

    cmd = klass.new(["testball", "nonexistent"])
    allow(cmd.args.named).to receive(:present?).and_return(true)
    allow(cmd.args.named).to receive(:to_formulae_and_casks_and_unavailable)
      .with(method: :resolve)
      .and_return([formula, error])

    allow(cmd).to receive_messages(upgrade_outdated_formulae!: true, upgrade_outdated_casks!: false)

    expect { cmd.run }
      .to output(/nonexistent/).to_stderr

    expect(Homebrew).to have_failed
  end

  it "catches cask upgrade errors and sets Homebrew.failed" do
    allow(Cask::Upgrade).to receive(:upgrade_casks!).and_raise(Cask::CaskError.new("test cask error"))

    cmd = klass.new(["--cask"])
    expect { cmd.send(:upgrade_outdated_casks!, []) }
      .to output(/test cask error/).to_stderr

    expect(Homebrew).to have_failed
  end

  it "does not ask again when upgrading discovered outdated casks" do
    cmd = klass.new(["--ask", "--cask"])

    expect(Homebrew::Install).not_to receive(:ask_casks)
    expect(Cask::Upgrade).to receive(:upgrade_casks!).and_return(true)

    cmd.send(:upgrade_outdated_casks!, [])
  end

  it "passes --no-quit to cask upgrades" do
    cmd = Homebrew::Cmd::UpgradeCmd.new(["--cask", "--no-quit"])

    expect(Cask::Upgrade).to receive(:upgrade_casks!) do |*_, **kwargs|
      expect(kwargs[:quit]).to be(false)
      true
    end

    cmd.send(:upgrade_outdated_casks!, [])
  end

  it "passes HOMEBREW_NO_UPGRADE_QUIT_CASKS to cask upgrades" do
    with_env("HOMEBREW_NO_UPGRADE_QUIT_CASKS" => "1") do
      cmd = Homebrew::Cmd::UpgradeCmd.new(["--cask"])

      expect(Cask::Upgrade).to receive(:upgrade_casks!) do |*_, **kwargs|
        expect(kwargs[:quit]).to be(false)
        true
      end

      cmd.send(:upgrade_outdated_casks!, [])
    end
  end

  # upgrades with asking for user prompts
  it "prints formula and cask ask plans before upgrading" do
    cmd = klass.new(["--ask"])
    download_queue = instance_double(Homebrew::DownloadQueue, fetch: nil, fetch_failed: false, shutdown: nil)

    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with([], dry_run: true, show_upgrade_summary: false)
      .ordered do
        cmd.send(:final_upgrade_summary).version_changes << "testball 0.1 -> 0.2"
        true
      end
    expect(cmd).to receive(:upgrade_outdated_casks!)
      .with([], dry_run: true, skip_prefetch: false, show_upgrade_summary: false, download_queue: nil)
      .ordered
      .and_return(true)
    allow(cmd).to receive(:show_final_upgrade_summary).and_call_original
    expect(cmd).to receive(:show_final_upgrade_summary).with(dry_run: true).ordered
    expect(Homebrew::Install).to receive(:ask).with(action: "upgrade")
                                              .ordered
    expect(Cask::Upgrade).to receive(:show_upgrade_summary)
      .with(["testball 0.1 -> 0.2"])
      .ordered
    expect(Homebrew::DownloadQueue).to receive(:new).ordered.and_return(download_queue)
    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with(
        [],
        prefetch_only:          true,
        download_queue:,
        prefetch_names:         [],
        prefetch_upgrades:      [],
        show_upgrade_summary:   false,
        show_downloads_heading: false,
      )
      .ordered
      .and_return(true)
    expect(cmd).to receive(:prefetch_outdated_casks!)
      .with(
        [],
        download_queue:,
        prefetch_names:         [],
        prefetch_upgrades:      [],
        show_downloads_heading: false,
      )
      .ordered
      .and_return(true)
    expect(download_queue).to receive(:fetch).ordered
    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with([], use_prefetched: true, show_upgrade_summary: false)
      .ordered
      .and_return(true)
    expect(cmd).to receive(:upgrade_outdated_casks!)
      .with([], skip_prefetch: true, show_upgrade_summary: false, download_queue: nil)
      .ordered
      .and_return(true)
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    cmd.run
  end

  it "does not ask before upgrading when nothing would upgrade" do
    cmd = klass.new(["--ask"])

    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with([], dry_run: true, show_upgrade_summary: false)
      .ordered
      .and_return(false)
    expect(cmd).to receive(:upgrade_outdated_casks!)
      .with([], dry_run: true, skip_prefetch: false, show_upgrade_summary: false, download_queue: nil)
      .ordered
      .and_return(false)
    expect(Homebrew::Install).not_to receive(:ask)
    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with([], use_prefetched: false, show_upgrade_summary: false)
      .ordered
      .and_return(false)
    expect(cmd).to receive(:upgrade_outdated_casks!)
      .with([], skip_prefetch: false, show_upgrade_summary: false, download_queue: nil)
      .ordered
      .and_return(false)
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    cmd.run
  end

  it "does not ask before upgrading only explicitly named formulae" do
    expect(Homebrew::Install.ask_prompt_needed?(
             planned_names:   ["testball"],
             requested_names: ["testball"],
           )).to be(false)
  end

  it "asks before upgrading formulae that resolve from a different name" do
    formula = formula("testball") do
      url "https://brew.sh/testball-0.2"
    end
    cmd = klass.new(["--ask", "oldtestball"])
    allow(cmd.args.named).to receive(:to_formulae_and_casks_and_unavailable)
      .with(method: :resolve)
      .and_return([formula])

    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with([formula], dry_run: true, show_upgrade_summary: false)
      .ordered do
        cmd.send(:final_upgrade_summary).version_changes << "testball 0.1 -> 0.2"
        true
      end
    allow(cmd).to receive(:show_final_upgrade_summary).and_call_original
    expect(cmd).to receive(:show_final_upgrade_summary).with(dry_run: true).ordered
    expect(Homebrew::Install).to receive(:ask).with(action: "upgrade").ordered
    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with([formula], use_prefetched: false, show_upgrade_summary: false)
      .ordered
      .and_return(true)
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    expect { cmd.run }.to output(/testball 0\.1 -> 0\.2/).to_stdout
  end

  it "prints formula download sizes in dry-run upgrade summaries" do
    cmd = klass.new(["--dry-run"])
    formula = formula("testball") do
      url "https://brew.sh/testball-0.2"
    end
    bottle = instance_double(Bottle, fetch_tab: nil, bottle_size: 500)
    keg = instance_double(Keg, version: PkgVersion.parse("0.1"), disk_usage: 1000)

    allow(formula).to receive_messages(optlinked?: true, opt_prefix: HOMEBREW_PREFIX/"opt/testball", bottle:)
    allow(Keg).to receive(:new).with(HOMEBREW_PREFIX/"opt/testball").and_return(keg)

    expect(cmd.send(:formula_upgrade_descriptions, [formula], include_sizes: true))
      .to eq(["testball 0.1 -> 0.2 (500B)"])
  end

  it "prints dry-run cleanup output from one formula cleanup run" do
    formula = formula("testball") do
      url "https://brew.sh/testball-0.2"
    end
    other_formula = formula("otherball") do
      url "https://brew.sh/otherball-0.2"
    end

    allow(Homebrew::Install).to receive(:print_dry_run_dependencies)
    allow(formula).to receive(:latest_version_installed?).and_return(true)
    allow(other_formula).to receive(:latest_version_installed?).and_return(true)
    expect(Homebrew::Cleanup).to receive(:dry_run_output)
      .with(formulae: [formula, other_formula])
      .and_return("Would remove: #{HOMEBREW_CELLAR}/testball/0.1 (1KB)\n")

    with_env(HOMEBREW_NO_ENV_HINTS: "1") do
      expect do
        Homebrew::Upgrade.upgrade_formulae(
          [FormulaInstaller.new(formula), FormulaInstaller.new(other_formula)],
          dry_run: true,
        )
      end.to output(<<~EOS).to_stdout
        ==> Would `brew cleanup`
        Would remove: #{HOMEBREW_CELLAR}/testball/0.1 (1KB)
      EOS
    end
  end

  it "omits dry-run dependencies already listed in the final summary" do
    formula = formula("yt-dlp") do
      url "https://brew.sh/yt-dlp-2026.3.17_2.tar.gz"
    end
    dependency_formula = formula("python@3.14") do
      url "https://brew.sh/python@3.14-3.14.5.tar.gz"
    end
    formula_installer = FormulaInstaller.new(formula)

    allow(formula_installer).to receive(:compute_dependencies)
      .and_return([instance_double(Dependency, to_formula: dependency_formula)])
    allow(Homebrew::Cleanup).to receive(:install_formula_clean!)

    expect do
      Homebrew::Upgrade.upgrade_formulae(
        [formula_installer],
        dry_run:            true,
        skip_formula_names: [dependency_formula.full_name],
      )
    end.not_to output.to_stdout
  end

  it "omits dry-run dependents already listed in the final summary" do
    formula = formula("sqlite") do
      url "https://brew.sh/sqlite-3.53.1.tar.gz"
    end
    dependent = formula("python@3.14") do
      url "https://brew.sh/python@3.14-3.14.5.tar.gz"
    end
    dependants = Homebrew::Upgrade::Dependents.new(upgradeable: [dependent], pinned: [], skipped: [])

    expect do
      Homebrew::Upgrade.upgrade_dependents(
        dependants,
        [formula],
        flags:              [],
        dry_run:            true,
        skip_formula_names: [dependent.full_name],
      )
    end.not_to output.to_stdout
  end

  it "does not print aggregate package sizes" do
    cmd = klass.new(["--dry-run"])
    summary = Homebrew::Cmd::UpgradeCmd::FinalUpgradeSummary.new(
      version_changes: ["testball 0.1 -> 0.2 (500B)", "codex 1.0 -> 2.0"],
    )

    allow(cmd).to receive(:final_upgrade_summary).and_return(summary)

    expect { cmd.send(:show_final_upgrade_summary) }.to output(<<~EOS).to_stdout
      ==> Would upgrade 2 outdated packages
      testball 0.1 -> 0.2 (500B)
      codex 1.0 -> 2.0
    EOS
  end

  it "uses the final summary for dry-run upgrade lists" do
    cmd = klass.new(["--dry-run"])

    expect(cmd).to receive(:upgrade_outdated_formulae!)
      .with([], use_prefetched: false, show_upgrade_summary: false)
      .and_return(true)
    expect(cmd).to receive(:upgrade_outdated_casks!)
      .with([], skip_prefetch: false, show_upgrade_summary: false, download_queue: nil)
      .and_return(true)
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    cmd.run
  end

  it "prints a combined upgrade summary before fetching combined downloads" do
    cmd = klass.new([])
    download_queue = instance_double(Homebrew::DownloadQueue, fetch: nil, fetch_failed: false, shutdown: nil)
    cask = instance_double(
      Cask::Cask,
      artifacts:         [],
      full_name:         "codex",
      installed_version: "0.117.0",
      version:           "0.118.0",
    )
    installer = instance_double(Cask::Installer, enqueue_downloads: nil, source_download_requires_pre_fetch?: false)

    expect(Homebrew::DownloadQueue).to receive(:new).once.and_return(download_queue)
    allow(cmd).to receive(:upgrade_outdated_formulae!) do |_, prefetch_only: false,
                                                              prefetch_names: nil,
                                                              prefetch_upgrades: nil,
                                                              show_upgrade_summary: true,
                                                              **|
      if prefetch_only
        expect(show_upgrade_summary).to be(false)
        prefetch_names&.replace(["deno"])
        prefetch_upgrades&.replace(["deno 2.7.10 -> 2.7.11"])
      end

      true
    end
    allow(Cask::Upgrade).to receive(:outdated_casks).and_return([cask])
    allow(Cask::Installer).to receive(:new).and_return(installer)
    allow(Cask::Upgrade).to receive(:upgrade_casks!) do |*_, **kwargs|
      expect(kwargs[:skip_prefetch]).to be(true)
      expect(kwargs[:show_upgrade_summary]).to be(false)

      true
    end
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    expect { cmd.run }.to output(<<~EOS).to_stdout
      ==> Upgrading 2 outdated packages:
      deno 2.7.10 -> 2.7.11
      codex 0.117.0 -> 0.118.0
      ==> Fetching downloads for: deno and codex
    EOS
  end

  it "asks before fetching formulae and casks in the same download queue" do
    cmd = klass.new(["--ask"])
    download_queue = instance_double(Homebrew::DownloadQueue, fetch: nil, fetch_failed: false, shutdown: nil)
    cask = instance_double(
      Cask::Cask,
      artifacts:         [],
      full_name:         "codex",
      installed_version: "0.117.0",
      version:           "0.118.0",
    )
    installer = instance_double(Cask::Installer, enqueue_downloads: nil, source_download_requires_pre_fetch?: false)

    allow(cmd).to receive(:upgrade_outdated_formulae!) do |_, dry_run: false, prefetch_only: false,
                                                              use_prefetched: false, prefetch_names: nil,
                                                              prefetch_upgrades: nil, **|
      if dry_run
        cmd.send(:final_upgrade_summary).version_changes << "deno 2.7.10 -> 2.7.11"
      elsif prefetch_only
        prefetch_names&.replace(["deno"])
        prefetch_upgrades&.replace(["deno 2.7.10 -> 2.7.11"])
      else
        expect(use_prefetched).to be(true)
      end

      true
    end
    allow(Cask::Upgrade).to receive(:outdated_casks).and_return([cask])
    allow(Cask::Installer).to receive(:new).and_return(installer)
    allow(Cask::Upgrade).to receive(:upgrade_casks!) do |*_, **kwargs|
      if kwargs[:dry_run]
        kwargs[:summary_upgrades] << "codex 0.117.0 -> 0.118.0"
      else
        expect(kwargs[:skip_prefetch]).to be(true)
      end

      true
    end
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    expect(Homebrew::Install).to receive(:ask).with(action: "upgrade").ordered
    expect(Homebrew::DownloadQueue).to receive(:new).ordered.and_return(download_queue)
    expect(Homebrew::Install).to receive(:enqueue_cask_installers).ordered
    expect(download_queue).to receive(:fetch).ordered

    cmd.run
  end

  it "prefetches language cask files before fetching combined downloads" do
    cmd = klass.new([])
    download_queue = instance_double(Homebrew::DownloadQueue, fetch_failed: false, shutdown: nil)
    cask = instance_double(
      Cask::Cask,
      artifacts:         [],
      full_name:         "codex",
      installed_version: "0.117.0",
      version:           "0.118.0",
    )
    installer = instance_double(
      Cask::Installer,
      enqueue_downloads:                   nil,
      source_download_requires_pre_fetch?: true,
    )
    source_download = instance_double(Homebrew::API::SourceDownload)

    expect(Homebrew::DownloadQueue).to receive(:new).once.and_return(download_queue)
    allow(cmd).to receive(:upgrade_outdated_formulae!) do |_, prefetch_only: false,
                                                              prefetch_names: nil,
                                                              prefetch_upgrades: nil,
                                                              show_upgrade_summary: true,
                                                              **|
      if prefetch_only
        expect(show_upgrade_summary).to be(false)
        prefetch_names&.replace(["deno"])
        prefetch_upgrades&.replace(["deno 2.7.10 -> 2.7.11"])
      end

      true
    end
    allow(Cask::Installer).to receive(:new).and_return(installer)
    expect(installer).to receive(:prelude_fetch_download).and_return(source_download)
    expect(download_queue).to receive(:enqueue).with(source_download).ordered
    expect(download_queue).to receive(:fetch).ordered
    expect(download_queue).to receive(:fetch).ordered
    allow(Cask::Upgrade).to receive_messages(outdated_casks: [cask], upgrade_casks!: true)
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    expect { cmd.run }.to output(<<~EOS).to_stdout
      ==> Downloading Cask files
      ==> Upgrading 2 outdated packages:
      deno 2.7.10 -> 2.7.11
      codex 0.117.0 -> 0.118.0
      ==> Fetching downloads for: deno and codex
    EOS
  end

  it "omits the cask file heading for cached language cask files" do
    cmd = klass.new([])
    download_queue = instance_double(Homebrew::DownloadQueue, fetch_failed: false, shutdown: nil)
    cask = instance_double(
      Cask::Cask,
      artifacts:         [],
      full_name:         "codex",
      installed_version: "0.117.0",
      version:           "0.118.0",
    )
    installer = instance_double(
      Cask::Installer,
      enqueue_downloads:                   nil,
      source_download_requires_pre_fetch?: true,
    )

    expect(Homebrew::DownloadQueue).to receive(:new).once.and_return(download_queue)
    allow(cmd).to receive(:upgrade_outdated_formulae!) do |_, prefetch_only: false,
                                                              prefetch_names: nil,
                                                              prefetch_upgrades: nil,
                                                              show_upgrade_summary: true,
                                                              **|
      if prefetch_only
        expect(show_upgrade_summary).to be(false)
        prefetch_names&.replace(["deno"])
        prefetch_upgrades&.replace(["deno 2.7.10 -> 2.7.11"])
      end

      true
    end
    allow(Cask::Installer).to receive(:new).and_return(installer)
    expect(installer).to receive(:prelude_fetch_download).and_return(nil)
    expect(download_queue).to receive(:fetch).once
    allow(Cask::Upgrade).to receive_messages(outdated_casks: [cask], upgrade_casks!: true)
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    expect { cmd.run }.to output(<<~EOS).to_stdout
      ==> Upgrading 2 outdated packages:
      deno 2.7.10 -> 2.7.11
      codex 0.117.0 -> 0.118.0
      ==> Fetching downloads for: deno and codex
    EOS
  end

  it "prints a bottle manifest heading before formula prefetches" do
    cmd = klass.new([])
    formula = formula("deno") do
      url "https://brew.sh/deno-2.7.11.tar.gz"

      bottle do
        root_url HOMEBREW_BOTTLE_DEFAULT_DOMAIN
        sha256 cellar: :any_skip_relocation,
               Utils::Bottles.tag.to_sym => "d7b9f4e8bf83608b71fe958a99f19f2e5e68bb2582965d32e41759c24f1aef97"
      end
    end

    allow(formula).to receive_messages(outdated?: true, latest_formula: formula, latest_version_installed?: false)
    allow(Homebrew::Install).to receive(:perform_preinstall_checks_once)
    allow(Homebrew::Upgrade).to receive(:formula_installers).and_return([])

    expect do
      cmd.send(:formulae_upgrade_context, [formula], show_upgrade_summary: false)
    end.to output("==> Downloading bottle manifests\n").to_stdout
  end

  it "omits the bottle manifest heading for cached formula manifests" do
    cmd = Homebrew::Cmd::UpgradeCmd.new([])
    formula = formula("deno") do
      url "https://brew.sh/deno-2.7.11.tar.gz"

      bottle do
        root_url HOMEBREW_BOTTLE_DEFAULT_DOMAIN
        sha256 cellar: :any_skip_relocation,
               Utils::Bottles.tag.to_sym => "d7b9f4e8bf83608b71fe958a99f19f2e5e68bb2582965d32e41759c24f1aef97"
      end
    end

    allow(formula).to receive_messages(outdated?: true, latest_formula: formula, latest_version_installed?: false)
    allow(formula.bottle&.github_packages_manifest_resource).to receive(:downloaded_and_valid?).and_return(true)
    allow(Homebrew::Install).to receive(:perform_preinstall_checks_once)
    allow(Homebrew::Upgrade).to receive(:formula_installers).and_return([])

    expect do
      cmd.send(:formulae_upgrade_context, [formula], show_upgrade_summary: false)
    end.not_to output(/Downloading bottle manifests/).to_stdout
  end

  it "does not trust failed shared prefetches" do
    cmd = klass.new([])
    download_queue = instance_double(Homebrew::DownloadQueue, fetch: nil, fetch_failed: true, shutdown: nil)
    cask = instance_double(
      Cask::Cask,
      artifacts:         [],
      full_name:         "codex",
      installed_version: "0.117.0",
      version:           "0.118.0",
    )
    installer = instance_double(Cask::Installer, enqueue_downloads: nil, source_download_requires_pre_fetch?: false)

    allow(Homebrew::DownloadQueue).to receive(:new).and_return(download_queue)
    allow(cmd).to receive(:upgrade_outdated_formulae!) do |_, prefetch_only: false,
                                                              use_prefetched: false,
                                                              prefetch_names: nil,
                                                              prefetch_upgrades: nil,
                                                              show_upgrade_summary: true,
                                                              **|
      if prefetch_only
        expect(show_upgrade_summary).to be(false)
        prefetch_names&.replace(["deno"])
        prefetch_upgrades&.replace(["deno 2.7.10 -> 2.7.11"])
      else
        expect(use_prefetched).to be(false)
        expect(show_upgrade_summary).to be(false)
      end

      true
    end
    allow(Cask::Upgrade).to receive(:outdated_casks).and_return([cask])
    allow(Cask::Installer).to receive(:new).and_return(installer)
    allow(Cask::Upgrade).to receive(:upgrade_casks!) do |*_, **kwargs|
      expect(kwargs[:skip_prefetch]).to be(false)
      expect(kwargs[:show_upgrade_summary]).to be(false)

      true
    end
    allow(Homebrew::Cleanup).to receive(:periodic_clean!)
    allow(Homebrew::Reinstall).to receive(:reinstall_pkgconf_if_needed!)
    allow(Homebrew.messages).to receive(:display_messages)

    cmd.run
  end

  it "does not print removed caveats method errors for installed casks", :cask do
    cask = Cask::CaskLoader.load(cask_path("local-caffeine"))
    installer = InstallHelper.install_with_caskfile(cask)
    installed_caskfile = installer.metadata_subdir/"#{cask.token}.rb"
    expect(installed_caskfile).to exist

    installed_caskfile.write(
      installed_caskfile.read.sub(
        /\nend\n\z/,
        <<~RUBY,
            caveats do
              discontinued
            end
          end
        RUBY
      ),
    )

    (CoreCaskTap.instance.cask_dir/"local-caffeine.rb").unlink
    CoreCaskTap.instance.clear_cache

    cmd = klass.new(["--cask", "--dry-run"])

    expect { cmd.send(:upgrade_outdated_casks!, []) }
      .to not_to_output(/Unexpected method 'discontinued' called during caveats on Cask local-caffeine\./).to_stderr
  end

  it "prints a narrow final upgrade summary" do
    cmd = klass.new([])
    summary = Homebrew::Cmd::UpgradeCmd::FinalUpgradeSummary.new(
      version_changes:       ["testball 0.1 -> 0.2"],
      pinned_formulae:       ["pinnedball 1.0"],
      pinned_casks:          ["pinned-cask 2.0"],
      deprecated:            ["oldball"],
      disabled:              ["disabledball"],
      source_build_formulae: ["sourceball"],
    )

    allow(cmd).to receive(:final_upgrade_summary).and_return(summary)

    expect { cmd.send(:show_final_upgrade_summary) }.to output(<<~EOS).to_stdout
      ==> Upgraded 1 outdated package
      testball 0.1 -> 0.2
      ==> 1 Pinned formula
      pinnedball 1.0
      ==> 1 Pinned cask
      pinned-cask 2.0
      ==> 2 Deprecated or disabled packages
      oldball (deprecated)
      disabledball (disabled)
      ==> 1 homebrew/core formula built from source
      sourceball
    EOS
  end

  it "records final formula upgrade summary details" do
    formula = formula("testball") do
      url "https://brew.sh/testball-0.2"
    end
    pinned = formula("pinnedball") do
      url "https://brew.sh/pinnedball-1.0"
    end
    deprecated = formula("oldball") do
      url "https://brew.sh/oldball-1.0"
      deprecate! date: "2020-01-01", because: :unmaintained
    end
    disabled = formula("disabledball") do
      url "https://brew.sh/disabledball-1.0"
      disable! date: "2020-01-01", because: :unsupported
    end
    source_build = formula("sourceball") do
      url "https://brew.sh/sourceball-1.0"
    end
    old_keg = HOMEBREW_CELLAR/"testball/0.1"
    old_keg.mkpath
    allow(formula).to receive_messages(optlinked?: true, opt_prefix: old_keg)

    cmd = klass.new([])
    context = Homebrew::Cmd::UpgradeCmd::FormulaeUpgradeContext.new(
      formulae_to_install: [formula, deprecated, disabled, source_build],
      formulae_installer:  [
        FormulaInstaller.new(formula),
        FormulaInstaller.new(deprecated),
        FormulaInstaller.new(disabled),
        FormulaInstaller.new(source_build, build_from_source_formulae: [source_build.full_name]),
      ],
      dependants:          Homebrew::Upgrade::Dependents.new(upgradeable: [], pinned: [], skipped: []),
      pinned_formulae:     [pinned],
    )

    cmd.send(:record_formula_upgrade_summary, context)
    summary = cmd.send(:final_upgrade_summary)

    expect(summary.version_changes).to include("testball 0.1 -> 0.2")
    expect(summary.pinned_formulae).to include("pinnedball 1.0")
    expect(summary.deprecated).to include("oldball")
    expect(summary.disabled).to include("disabledball")
    expect(summary.source_build_formulae).to include("sourceball")
  end

  it "records formula upgrade versions before upgrading" do
    formula = formula("testball") do
      url "https://brew.sh/testball-0.2"
    end
    old_keg = HOMEBREW_CELLAR/"testball/0.1"
    new_keg = HOMEBREW_CELLAR/"testball/0.2"
    old_keg.mkpath
    new_keg.mkpath
    allow(formula).to receive_messages(optlinked?: true, opt_prefix: old_keg)
    cmd = klass.new([])

    allow(cmd).to receive(:formulae_upgrade_context).and_return(
      Homebrew::Cmd::UpgradeCmd::FormulaeUpgradeContext.new(
        formulae_to_install: [formula],
        formulae_installer:  [FormulaInstaller.new(formula)],
        dependants:          Homebrew::Upgrade::Dependents.new(upgradeable: [], pinned: [], skipped: []),
      ),
    )
    allow(Homebrew::Upgrade).to receive(:upgrade_formulae) do
      allow(formula).to receive(:opt_prefix).and_return(new_keg)
    end
    allow(Homebrew::Upgrade).to receive(:upgrade_dependents)

    cmd.send(:upgrade_outdated_formulae!, [])

    expect(cmd.send(:final_upgrade_summary).version_changes).to include("testball 0.1 -> 0.2")
  end

  it_behaves_like "reinstall_pkgconf_if_needed"
end
