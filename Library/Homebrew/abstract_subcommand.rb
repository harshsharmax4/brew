# typed: strict
# frozen_string_literal: true

require "cli/parser"
require "abstract_command"
require "utils/output"

module Homebrew
  # Subclass this to implement a subcommand for a `brew` command.
  #
  # @api public
  class AbstractSubcommand
    extend T::Helpers
    include Utils::Output::Mixin

    abstract!

    class << self
      sig { returns(String) }
      def subcommand_name
        require "utils"

        class_name = name
        raise TypeError, "anonymous subcommands do not have names" if class_name.nil?

        Utils.underscore(class_name.split("::").fetch(-1))
             .tr("_", "-")
             .delete_suffix("-subcommand")
      end

      sig { params(command: T.class_of(Homebrew::AbstractCommand)).returns(T::Array[T.class_of(AbstractSubcommand)]) }
      def subcommands_for(command)
        namespace = "#{command.name}::"
        subclasses.select do |subcommand|
          subcommand.name&.start_with?(namespace)
        end
      end

      sig { params(parser: CLI::Parser, command: T.class_of(Homebrew::AbstractCommand)).void }
      def define_all(parser, command:)
        subcommands_for(command).each do |subcommand|
          subcommand.define(parser)
        end
      end

      sig { params(parser: CLI::Parser).void }
      def define(parser)
        parser_block = @parser_block
        raise TypeError, "subcommand arguments have not been defined" if parser_block.nil?

        parser.subcommand(
          subcommand_name,
          aliases:       @aliases || [],
          alias_options: @alias_options || {},
          default:       @default || false,
        ) do
          instance_eval(&parser_block)
        end
      end

      private

      # The description and arguments of the subcommand should be defined within this block.
      #
      # @api public
      sig {
        params(
          aliases:       T::Array[String],
          alias_options: T::Hash[String, String],
          default:       T::Boolean,
          block:         T.proc.bind(CLI::Parser).void,
        ).void
      }
      def subcommand_args(aliases: [], alias_options: {}, default: false, &block)
        @aliases = T.let(aliases, T.nilable(T::Array[String]))
        @alias_options = T.let(alias_options, T.nilable(T::Hash[String, String]))
        @default = T.let(default, T.nilable(T::Boolean))
        @parser_block = T.let(block, T.nilable(T.proc.void))
      end
    end

    sig { returns(T.untyped) }
    attr_reader :args

    sig { params(args: T.untyped, context: T.untyped, targets: T.untyped, quiet: T::Boolean, cleanup: T::Boolean).void }
    def initialize(args, context: nil, targets: nil, quiet: false, cleanup: true)
      @args = args
      @context = context
      @targets = targets
      @quiet = quiet
      @cleanup = cleanup
    end

    sig { returns(T.untyped) }
    attr_reader :context

    sig { returns(T.untyped) }
    attr_reader :targets

    sig { returns(T::Boolean) }
    attr_reader :quiet

    sig { returns(T::Boolean) }
    attr_reader :cleanup

    # This method will be invoked when the subcommand is run.
    #
    # @api public
    sig { abstract.void }
    def run; end
  end
end
