# typed: false
# frozen_string_literal: true

require "abstract_command"
require "abstract_subcommand"

RSpec.describe Homebrew::AbstractSubcommand do
  let(:klass) { Homebrew::AbstractSubcommand }

  describe "subclasses" do
    before do
      subcommand = Class.new(klass) do
        subcommand_args aliases: ["ts"], default: true do
          usage_banner <<~EOS
            `brew test`:
            Run the test subcommand.
          EOS
          switch "--foo"
          named_args :none
        end

        def run; end
      end
      stub_const("TestSubcommand", subcommand)
      stub_const("SubcommandTestCmd", Class.new(Homebrew::AbstractCommand))
    end

    it "defines parser metadata from subcommand_args" do
      parser = Homebrew::CLI::Parser.new(SubcommandTestCmd) do
        TestSubcommand.define(self)
      end

      expect(parser.subcommands.first.name).to eq("test")
      expect(parser.subcommands.first.aliases).to eq(["ts"])
      expect(parser.subcommands.first.default).to be(true)
      expect(parser.processed_options_for_subcommand("test").map(&:second)).to include("--foo")
    end

    it "allows access to args" do
      expect(TestSubcommand.new(:args).args).to eq(:args)
    end

    it "finds subcommands nested under a command class" do
      nested_subcommand = Class.new(klass) do
        subcommand_args { named_args :none }
        def run; end
      end
      stub_const("SubcommandTestCmd::NestedSubcommand", nested_subcommand)
      stub_const("OtherSubcommandTestCmd", Class.new(Homebrew::AbstractCommand))
      other_subcommand = Class.new(klass) do
        subcommand_args { named_args :none }
        def run; end
      end
      stub_const("OtherSubcommandTestCmd::NestedSubcommand", other_subcommand)

      expect(klass.subcommands_for(SubcommandTestCmd)).to include(nested_subcommand)
      expect(klass.subcommands_for(SubcommandTestCmd)).not_to include(other_subcommand)
    end

    it "defines all subcommands nested under a command class" do
      stub_const("SubcommandTestCmd::FirstSubcommand", Class.new(klass) do
        subcommand_args { named_args :none }
        def run; end
      end)
      stub_const("SubcommandTestCmd::SecondSubcommand", Class.new(klass) do
        subcommand_args { named_args :none }
        def run; end
      end)

      abstract_subcommand = klass
      parser = Homebrew::CLI::Parser.new(SubcommandTestCmd) do
        abstract_subcommand.define_all(self, command: SubcommandTestCmd)
      end

      expect(parser.subcommand_names).to include("first", "second")
    end
  end
end
