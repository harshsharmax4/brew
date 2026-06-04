# typed: strict
# frozen_string_literal: true

require "cmd/completions"
require "cmd/shared_examples/args_parse"

RSpec.describe Homebrew::Cmd::CompletionsCmd do
  it_behaves_like "parseable arguments"

  it "uses state as the default subcommand" do
    expect(Homebrew::Cmd::CompletionsCmd.new([]).args.subcommand).to eq("state")
  end

  it "rejects extra arguments for state" do
    expect { Homebrew::Cmd::CompletionsCmd.new(%w[state foo]) }
      .to raise_error(Homebrew::CLI::MaxNamedArgumentsError)
  end

  it "runs the status subcommand correctly", :integration_test do
    HOMEBREW_REPOSITORY.cd do
      system "git", "init"
    end

    brew "completions", "link"
    expect { brew "completions" }
      .to output(/Completions are linked/).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end
end
