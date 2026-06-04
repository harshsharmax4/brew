# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/cat"

RSpec.describe Homebrew::DevCmd::Cat do
  it_behaves_like "parseable arguments"

  it "uses a system bat when configured" do
    formula_file = Formulary.find_formula_in_tap("testball", CoreTap.instance)
    formula_file.dirname.mkpath
    formula_file.write <<~RUBY
      class Testball < Formula
        url "https://brew.sh/testball-1.0"
      end
    RUBY
    CoreTap.instance.clear_cache

    cat = Homebrew::DevCmd::Cat.new(["testball"])
    formula = instance_double(Formula)

    allow(Homebrew::EnvConfig).to receive_messages(bat?: true, bat_config_path: "/tmp/bat.conf", bat_theme: "ansi")
    allow(Formula).to receive(:[]).with("bat").and_return(formula)
    allow(formula).to receive(:ensure_installed!).with(
      reason:           "displaying <formula>/<cask> source",
      output_to_stderr: true,
      executable:       "bat",
    ).and_return(Pathname.new("/usr/bin/bat"))

    expect(cat).to receive(:safe_system).with(Pathname.new("/usr/bin/bat"), formula_file)

    cat.run
  end

  it "prints the content of a given Formula", :integration_test do
    formula_file = setup_test_formula "testball"
    content = formula_file.read

    expect { brew "cat", "testball" }
      .to output(content).to_stdout
      .and not_to_output.to_stderr
      .and be_a_success
  end
end
