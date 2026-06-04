# typed: false
# frozen_string_literal: true

require "exceptions"

RSpec.describe "Exception" do
  describe MultipleVersionsInstalledError do
    subject(:error) do
      klass.new <<~EOS
        foo has multiple installed versions
        Run `brew uninstall --force foo` to remove all versions.
      EOS
    end

    let(:klass) { MultipleVersionsInstalledError }

    it(:to_s) do
      expect(error.to_s).to eq <<~EOS
        foo has multiple installed versions
        Run `brew uninstall --force foo` to remove all versions.
      EOS
    end
  end

  describe NoSuchKegError do
    let(:klass) { NoSuchKegError }

    context "without a tap" do
      subject(:error) { klass.new("foo") }

      it(:to_s) { expect(error.to_s).to eq("No such keg: #{HOMEBREW_CELLAR}/foo") }
    end

    context "with a tap" do
      subject(:error) { klass.new("foo", tap:) }

      let(:tap) { instance_double(Tap, to_s: "u/r") }

      it(:to_s) { expect(error.to_s).to eq("No such keg: #{HOMEBREW_CELLAR}/foo from tap u/r") }
    end
  end

  describe FormulaValidationError do
    subject(:error) { klass.new("foo", "sha257", "magic") }

    let(:klass) { FormulaValidationError }

    it(:to_s) do
      expect(error.to_s).to eq(%q(invalid attribute for formula 'foo': sha257 ("magic")))
    end
  end

  describe TapFormulaOrCaskUnavailableError do
    subject(:error) { klass.new(tap, "foo") }

    let(:klass) { TapFormulaOrCaskUnavailableError }
    let(:tap) { instance_double(Tap, user: "u", repository: "r", to_s: "u/r", installed?: false) }

    it(:to_s) {
      expect(error.to_s).to match(%r{If you trust this tap, tap it explicitly and then try again:\n  brew tap u/r})
    }
  end

  describe FormulaUnavailableError do
    subject(:error) { klass.new("foo") }

    let(:klass) { FormulaUnavailableError }

    describe "#dependent_s" do
      it "returns nil if there is no dependent" do
        expect(error.dependent_s).to be_nil
      end

      it "returns nil if it depended on by itself" do
        error.dependent = "foo"
        expect(error.dependent_s).to be_nil
      end

      it "returns a string if there is a dependent" do
        error.dependent = "foobar"
        expect(error.dependent_s).to eq(" (dependency of foobar)")
      end
    end

    context "without a dependent" do
      it(:to_s) { expect(error.to_s).to match(/^No available formula with the name "foo"\./) }
    end

    context "with a dependent" do
      before do
        error.dependent = "foobar"
      end

      it(:to_s) do
        expect(error.to_s).to match(/^No available formula with the name "foo" \(dependency of foobar\)\./)
      end
    end
  end

  describe TapFormulaUnavailableError do
    subject(:error) { klass.new(tap, "foo") }

    let(:klass) { TapFormulaUnavailableError }
    let(:tap) { instance_double(Tap, user: "u", repository: "r", to_s: "u/r", installed?: false) }

    it(:to_s) {
      expect(error.to_s).to match(%r{If you trust this tap, tap it explicitly and then try again:\n  brew tap u/r})
    }
  end

  describe FormulaClassUnavailableError do
    subject(:error) { klass.new("foo", "foo.rb", "Foo", list) }

    let(:klass) { FormulaClassUnavailableError }
    let(:mod) do
      Module.new do
        const_set :Bar, Class.new(Requirement)
        const_set :Baz, Class.new(Formula)
      end
    end

    context "when there are no classes" do
      let(:list) { [] }

      it(:to_s) do
        expect(error.to_s).to match(/Expected to find class Foo, but found no classes\./)
      end
    end

    context "when the class is not derived from Formula" do
      let(:list) { [mod.const_get(:Bar)] }

      it(:to_s) do
        expect(error.to_s).to match(/Expected to find class Foo, but only found: Bar \(not derived from Formula!\)\./)
      end
    end

    context "when the class is derived from Formula" do
      let(:list) { [mod.const_get(:Baz)] }

      it(:to_s) { expect(error.to_s).to match(/Expected to find class Foo, but only found: Baz\./) }
    end
  end

  describe FormulaUnreadableError do
    subject(:error) { klass.new("foo", formula_error) }

    let(:klass) { FormulaUnreadableError }
    let(:formula_error) { LoadError.new("bar") }

    it(:to_s) { expect(error.to_s).to eq("foo: bar") }
  end

  describe TapUnavailableError do
    subject(:error) { klass.new("foo") }

    let(:klass) { TapUnavailableError }

    it(:to_s) { expect(error.to_s).to eq("No available tap foo.\nRun brew tap-new foo to create a new foo tap!\n") }
  end

  describe TapAlreadyTappedError do
    subject(:error) { klass.new("foo") }

    let(:klass) { TapAlreadyTappedError }

    it(:to_s) { expect(error.to_s).to eq("Tap foo already tapped.\n") }
  end

  describe BuildError do
    subject(:error) { klass.new(formula, "badprg", ["arg1", 2, Pathname.new("arg3"), :arg4], {}) }

    let(:klass) { BuildError }
    let(:formula) { instance_double(Formula, name: "foo") }

    it(:to_s) { expect(error.to_s).to eq("Failed executing: badprg arg1 2 arg3 arg4") }
  end

  describe OperationInProgressError do
    subject(:error) { klass.new(Pathname("foo")) }

    let(:klass) { OperationInProgressError }

    it(:to_s) { expect(error.to_s).to match(/has already locked foo/) }
  end

  describe FormulaInstallationAlreadyAttemptedError do
    subject(:error) { klass.new(formula) }

    let(:klass) { FormulaInstallationAlreadyAttemptedError }
    let(:formula) { instance_double(Formula, full_name: "foo/bar") }

    it(:to_s) { expect(error.to_s).to eq("Formula installation already attempted: foo/bar") }
  end

  describe FormulaConflictError do
    subject(:error) { klass.new(formula, [conflict]) }

    let(:klass) { FormulaConflictError }
    let(:formula) { instance_double(Formula, full_name: "foo/qux") }
    let(:conflict) { instance_double(Formula::FormulaConflict, name: "bar", reason: "I decided to") }

    it(:to_s) { expect(error.to_s).to match(/Please `brew unlink bar` before continuing\./) }
  end

  describe CompilerSelectionError do
    subject(:error) { klass.new(formula) }

    let(:klass) { CompilerSelectionError }
    let(:formula) { instance_double(Formula, full_name: "foo") }

    it(:to_s) { expect(error.to_s).to match(/foo cannot be built with any available compilers\./) }
  end

  describe CurlDownloadStrategyError do
    let(:klass) { CurlDownloadStrategyError }

    context "when the file does not exist" do
      subject(:error) { klass.new("file:///tmp/foo") }

      it(:to_s) { expect(error.to_s).to eq("File cannot be read: /tmp/foo") }
    end

    context "when the download failed" do
      subject(:error) { klass.new("https://brew.sh") }

      it(:to_s) { expect(error.to_s).to eq("Download failed: https://brew.sh") }
    end
  end

  describe ErrorDuringExecution do
    subject(:error) { klass.new(["badprg", "arg1", "arg2"], status:) }

    let(:klass) { ErrorDuringExecution }
    let(:status) { instance_double(Process::Status, exitstatus: 17, termsig: nil) }

    it(:to_s) { expect(error.to_s).to eq("Failure while executing; `badprg arg1 arg2` exited with 17.") }
  end

  describe ChecksumMismatchError do
    subject(:error) { klass.new("/file.tar.gz", expected_checksum, actual_checksum) }

    let(:klass) { ChecksumMismatchError }
    let(:expected_checksum) { instance_double(Checksum, to_s: "deadbeef") }
    let(:actual_checksum) { instance_double(Checksum, to_s: "deadcafe") }

    it(:to_s) { expect(error.to_s).to match(/SHA-256 mismatch/) }

    it "does not add an HTML hint for non-HTML downloads" do
      Tempfile.create("brew-checksum-test") do |file|
        file.binmode
        file.write("PK\x03\x04binary-content")
        file.flush
        message = klass.new(Pathname(file.path), expected_checksum, actual_checksum).to_s
        expect(message).not_to match(%r{HTML/XML})
      end
    end

    it "adds an HTML hint when the download is an HTML page" do
      Tempfile.create("brew-checksum-test") do |file|
        file.binmode
        file.write('<!doctype html><html lang="en"><head><title>Oh noes!</title>')
        file.flush
        message = klass.new(Pathname(file.path), expected_checksum, actual_checksum).to_s
        expect(message).to match(%r{HTML/XML, not a binary})
      end
    end
  end

  describe ResourceMissingError do
    subject(:error) { klass.new(formula, resource) }

    let(:klass) { ResourceMissingError }
    let(:formula) { instance_double(Formula, full_name: "bar") }
    let(:resource) { instance_double(Resource, inspect: "<resource foo>") }

    it(:to_s) { expect(error.to_s).to eq("bar does not define resource <resource foo>") }
  end

  describe DuplicateResourceError do
    subject(:error) { klass.new(resource) }

    let(:klass) { DuplicateResourceError }
    let(:resource) { instance_double(Resource, inspect: "<resource foo>") }

    it(:to_s) { expect(error.to_s).to eq("Resource <resource foo> is defined more than once") }
  end

  describe BottleFormulaUnavailableError do
    subject(:error) { klass.new("/foo.bottle.tar.gz", "foo/1.0/.brew/foo.rb") }

    let(:klass) { BottleFormulaUnavailableError }
    let(:formula) { instance_double(Formula, full_name: "foo") }

    it(:to_s) { expect(error.to_s).to match(/This bottle does not contain the formula file/) }
  end

  describe BuildFlagsError do
    subject(:error) { klass.new(["-s"]) }

    let(:klass) { BuildFlagsError }

    it(:to_s) { expect(error.to_s).to match(/flag:\s+-s\nrequires building tools/) }
  end
end
