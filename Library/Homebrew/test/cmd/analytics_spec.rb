# typed: strict
# frozen_string_literal: true

require "cmd/analytics"
require "cmd/shared_examples/args_parse"

RSpec.describe Homebrew::Cmd::Analytics do
  it_behaves_like "parseable arguments"

  it "uses state as the default subcommand" do
    expect(Homebrew::Cmd::Analytics.new([]).args.subcommand).to eq("state")
  end

  it "rejects extra arguments for state" do
    expect { Homebrew::Cmd::Analytics.new(%w[state foo]) }
      .to raise_error(Homebrew::CLI::MaxNamedArgumentsError)
  end

  it "when HOMEBREW_NO_ANALYTICS is unset is disabled after running `brew analytics off`", :integration_test do
    HOMEBREW_REPOSITORY.cd do
      system "git", "init"
    end

    brew "analytics", "off"
    expect { brew "analytics", "HOMEBREW_NO_ANALYTICS" => nil }
      .to output(/analytics are disabled/i).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end
end
