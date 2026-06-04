# typed: false
# frozen_string_literal: true

require "sandbox"

RSpec.describe Sandbox do
  subject(:sandbox) { klass.new }

  let(:klass) { Sandbox }

  describe "::failure_reason" do
    let(:sandbox_class) { Class.new(klass) }

    it "returns nil if the sandbox is available" do
      allow(sandbox_class).to receive(:state).and_return(:available)

      expect(sandbox_class.failure_reason).to be_nil
    end

    it "returns a sandbox failure reason if the sandbox is unavailable" do
      allow(sandbox_class).to receive(:state).and_return(:unavailable)

      expect(sandbox_class.failure_reason).to match(/sandbox/i)
    end
  end

  describe "::executable" do
    let(:sandbox_class) do
      Class.new(klass) do
        class << self
          attr_accessor :test_executable_name, :unsuitable_executables

          def executable_name = test_executable_name

          def executable_usable?(candidate)
            unsuitable_executables.exclude?(candidate)
          end
        end
      end
    end
    let(:first_dir) { mktmpdir }
    let(:second_dir) { mktmpdir }
    let(:homebrew_bin) { mktmpdir }
    let(:executable_name) { "sandbox-tool" }
    let(:first_executable) { first_dir/executable_name }
    let(:second_executable) { second_dir/executable_name }
    let(:homebrew_executable) { homebrew_bin/executable_name }

    before do
      sandbox_class.test_executable_name = executable_name
      sandbox_class.unsuitable_executables = []
      stub_const("HOMEBREW_ORIGINAL_BREW_FILE", homebrew_bin/"brew")
    end

    it "uses the first suitable executable candidate" do
      FileUtils.touch first_executable
      FileUtils.chmod "+x", first_executable
      FileUtils.touch second_executable
      FileUtils.chmod "+x", second_executable
      stub_const("ORIGINAL_PATHS", [first_dir])

      with_env(PATH: second_dir.to_s) do
        expect(sandbox_class.executable).to eq(first_executable)
      end
    end

    it "skips unsuitable executable candidates" do
      FileUtils.touch first_executable
      FileUtils.chmod "+x", first_executable
      FileUtils.touch second_executable
      FileUtils.chmod "+x", second_executable
      stub_const("ORIGINAL_PATHS", [first_dir])
      sandbox_class.unsuitable_executables = [first_executable]

      with_env(PATH: second_dir.to_s) do
        expect(sandbox_class.executable).to eq(second_executable)
      end
    end

    it "falls back to the original Homebrew bin directory" do
      FileUtils.touch homebrew_executable
      FileUtils.chmod "+x", homebrew_executable
      stub_const("ORIGINAL_PATHS", [])

      with_env(PATH: mktmpdir.to_s) do
        expect(sandbox_class.executable).to eq(homebrew_executable)
      end
    end

    it "checks absolute executable paths directly" do
      FileUtils.touch first_executable
      FileUtils.chmod "+x", first_executable
      sandbox_class.test_executable_name = first_executable.to_s
      stub_const("ORIGINAL_PATHS", [])

      with_env(PATH: mktmpdir.to_s) do
        expect(sandbox_class.executable).to eq(first_executable)
      end
    end

    it "raises when no executable candidate exists" do
      stub_const("ORIGINAL_PATHS", [])

      with_env(PATH: mktmpdir.to_s) do
        expect { sandbox_class.executable! }
          .to raise_error(RuntimeError, "#{executable_name} is required to use the sandbox.")
      end
    end
  end

  describe "#path_filter" do
    ["'", '"', "(", ")", "\n", "\\"].each do |char|
      it "fails if the path contains #{char}" do
        expect do
          sandbox.path_filter("foo#{char}bar", :subpath)
        end.to raise_error(ArgumentError)
      end
    end
  end

  describe "#allow_read_if_exists" do
    it "allows reads for existing paths" do
      file = mktmpdir/"foo.rb"
      FileUtils.touch file

      sandbox.allow_read_if_exists path: file

      rule = sandbox.send(:profile).rules.fetch(-1)
      expect(rule).to have_attributes(allow: true, operation: "file-read*")
      expect(rule.filter).to have_attributes(path: file.realpath.to_s, type: :literal)
    end

    it "skips missing paths" do
      sandbox.allow_read_if_exists path: mktmpdir/"missing.rb"

      expect(sandbox.send(:profile).rules).to be_empty
    end

    it "skips nil paths" do
      sandbox.allow_read_if_exists path: nil

      expect(sandbox.send(:profile).rules).to be_empty
    end
  end

  describe "#deny_read_path" do
    it "denies reads for a subpath" do
      dir = mktmpdir/"foo"
      dir.mkpath

      sandbox.deny_read_path dir

      rule = sandbox.send(:profile).rules.fetch(-1)
      expect(rule).to have_attributes(allow: false, operation: "file-read*")
      expect(rule.filter).to have_attributes(path: dir.realpath.to_s, type: :subpath)
    end
  end

  describe "#deny_read_home" do
    let(:home) { mktmpdir/"home" }
    let(:prefix) { mktmpdir/"prefix" }
    let(:repository) { mktmpdir/"repository" }
    let(:temp) { mktmpdir/"tmp" }
    let(:cache) { mktmpdir/"cache" }

    before do
      [home, prefix, repository, temp, cache].each(&:mkpath)
      allow(Dir).to receive(:home).with(ENV.fetch("USER")).and_return(home.to_s)
      stub_const("HOMEBREW_PREFIX", prefix)
      stub_const("HOMEBREW_REPOSITORY", repository)
      stub_const("HOMEBREW_TEMP", temp)
      stub_const("HOMEBREW_CACHE", cache)
    end

    it "denies reads from the real home" do
      sandbox.deny_read_home

      rule = sandbox.send(:profile).rules.fetch(-1)
      expect(rule).to have_attributes(allow: false, operation: "file-read*")
      expect(rule.filter).to have_attributes(path: home.realpath.to_s, type: :subpath)
    end

    [
      [:HOMEBREW_PREFIX, "prefix"],
      [:HOMEBREW_REPOSITORY, "repository"],
      [:HOMEBREW_CACHE, "cache"],
      [:HOMEBREW_TEMP, "tmp"],
    ].each do |constant, directory|
      it "skips the deny when #{constant} is inside the real home" do
        stub_const(constant.to_s, home/directory)
        Object.const_get(constant).mkpath

        sandbox.deny_read_home

        expect(sandbox.send(:profile).rules).to be_empty
      end
    end

    [
      ["GITHUB_WORKSPACE", "workspace"],
      ["RUNNER_WORKSPACE", "runner-workspace"],
      ["RUNNER_TEMP", "runner-temp"],
    ].each do |env, directory|
      it "skips the deny when #{env} is inside the real home" do
        (home/directory).mkpath

        with_env(env => (home/directory).to_s) do
          sandbox.deny_read_home
        end

        expect(sandbox.send(:profile).rules).to be_empty
      end
    end

    it "skips the deny when a runner path resolves inside the real home" do
      (home/"workspace").mkpath
      workspace_link = mktmpdir/"workspace"
      FileUtils.ln_s home/"workspace", workspace_link

      with_env(GITHUB_WORKSPACE: workspace_link.to_s) do
        sandbox.deny_read_home
      end

      expect(sandbox.send(:profile).rules).to be_empty
    end

    it "denies sensitive home paths when the real home cannot be denied" do
      [".ssh", "Documents", "Library/Keychains", "Library/Mobile Documents", "Dropbox"].each do |directory|
        (home/directory).mkpath
      end

      with_env(GITHUB_WORKSPACE: (home/"workspace").to_s) do
        sandbox.deny_read_home
      end

      expect(sandbox.send(:profile).rules.map { |rule| rule.filter&.path }).to eq(
        [
          home/".ssh",
          home/"Documents",
          home/"Library/Keychains",
          home/"Library/Mobile Documents",
          home/"Dropbox",
        ].map { |path| path.realpath.to_s },
      )
    end
  end

  describe "#allow_write_path_if_exists" do
    it "allows writes for existing paths" do
      dir = mktmpdir/"foo"
      dir.mkpath

      sandbox.allow_write_path_if_exists dir

      rule = sandbox.send(:profile).rules.fetch(0)
      expect(rule).to have_attributes(allow: true, operation: "file-write*")
      expect(rule.filter).to have_attributes(path: dir.realpath.to_s, type: :subpath)
    end

    it "skips missing paths" do
      sandbox.allow_write_path_if_exists mktmpdir/"missing"

      expect(sandbox.send(:profile).rules).to be_empty
    end

    it "skips nil paths" do
      sandbox.allow_write_path_if_exists nil

      expect(sandbox.send(:profile).rules).to be_empty
    end
  end

  describe "#allow_write_cellar" do
    it "fails when the formula has a name including )" do
      f = formula do
        url "https://brew.sh/foo-1.0.tar.gz"
        version "1.0"

        def initialize(*, **)
          super
          @name = "foo)bar"
        end
      end

      expect do
        sandbox.allow_write_cellar f
      end.to raise_error(ArgumentError)
    end

    it "fails when the formula has a name including \"" do
      f = formula do
        url "https://brew.sh/foo-1.0.tar.gz"
        version "1.0"

        def initialize(*, **)
          super
          @name = "foo\"bar"
        end
      end

      expect do
        sandbox.allow_write_cellar f
      end.to raise_error(ArgumentError)
    end
  end
end
