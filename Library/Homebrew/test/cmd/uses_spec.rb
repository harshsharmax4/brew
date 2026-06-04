# typed: true
# frozen_string_literal: true

require "cli/named_args"
require "cmd/shared_examples/args_parse"
require "cmd/uses"
require "fileutils"

RSpec.describe Homebrew::Cmd::Uses do
  let(:klass) { Homebrew::Cmd::Uses }

  include FileUtils

  it_behaves_like "parseable arguments"

  it "uses tap trust environment to evaluate all formulae" do
    used_formula = instance_double(Formula, full_name: "foo")
    cmd = klass.new(["--formula", "foo"])

    allow(cmd.args.named).to receive(:to_formulae).and_return([used_formula])
    expect(Formula).to receive(:all).with(eval_all: true).and_return([])

    expect { with_env(HOMEBREW_REQUIRE_TAP_TRUST: "1") { cmd.run } }
      .to not_to_output.to_stderr
  end

  it "prints the Formulae a given Formula is used by", :integration_test, :no_api do
    # Included in output
    setup_test_formula "bar"
    setup_test_formula "optional", <<~RUBY
      url "https://brew.sh/optional-1.0"
      depends_on "bar" => :optional
    RUBY

    # Excluded from output
    setup_test_formula "foo"
    setup_test_formula "test", <<~RUBY
      url "https://brew.sh/test-1.0"
      depends_on "foo" => :test
    RUBY
    setup_test_formula "build", <<~RUBY
      url "https://brew.sh/build-1.0"
      depends_on "foo" => :build
    RUBY
    setup_test_formula "installed", <<~RUBY
      url "https://brew.sh/installed-1.0"
      depends_on "foo"
    RUBY

    # Mock `Formula#any_version_installed?` by creating the tab in a plausible keg directory
    %w[foo installed].each do |formula_name|
      keg_dir = HOMEBREW_CELLAR/formula_name/"1.0"
      keg_dir.mkpath
      touch keg_dir/AbstractTab::FILENAME
    end

    expect do
      brew "uses", "foo", "--include-optional", "--missing", "--recursive", "HOMEBREW_NO_REQUIRE_TAP_TRUST" => "1"
    end
      .to output(/^(bar\noptional|optional\nbar)$/).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end

  it "handles unavailable formula" do
    expect_any_instance_of(Homebrew::CLI::NamedArgs)
      .to receive(:to_formulae)
      .and_raise(FormulaUnavailableError, "foo")
    cmd = klass.new(%w[foo --include-optional --recursive])
    allow(cmd).to receive(:intersection_of_dependents)
      .and_return([
        instance_double(Formula, full_name: "bar"),
        instance_double(Formula, full_name: "optional"),
      ])

    expect { with_env(HOMEBREW_NO_REQUIRE_TAP_TRUST: "1") { cmd.run } }
      .to output(/^(bar\noptional|optional\nbar)$/).to_stdout
      .and output(/Error: Missing formulae should not have dependents!\n/).to_stderr
      .and raise_error SystemExit
  end
end
