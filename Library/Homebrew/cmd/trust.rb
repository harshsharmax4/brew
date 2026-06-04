# typed: strict
# frozen_string_literal: true

require "abstract_command"
require "trust"

module Homebrew
  module Cmd
    class Trust < AbstractCommand
      cmd_args do
        description <<~EOS
          Trust non-official tap formulae, casks or commands so Homebrew may load them when
          `$HOMEBREW_REQUIRE_TAP_TRUST` is set.
          Trusted entries are stored in `${XDG_CONFIG_HOME}/homebrew/trust.json` if
          `$XDG_CONFIG_HOME` is set or `~/.homebrew/trust.json` otherwise.
        EOS
        switch "--tap",
               description: "Trust the named tap."
        switch "--formula", "--formulae",
               description: "Trust the named formula."
        switch "--cask", "--casks",
               description: "Trust the named cask."
        switch "--command", "--commands",
               description: "Trust the named external command."

        conflicts "--tap", "--formula", "--cask", "--command"

        named_args :target
      end

      sig { override.void }
      def run
        if args.no_named?
          puts "All official taps and commands are trusted."
          types = selected_type ? [selected_type] : [:tap, :formula, :cask, :command]
          printed = T.let(false, T::Boolean)
          types.each do |type|
            values = Homebrew::Trust.trusted_entries(type)
            next if values.empty?

            label = case type
            when :tap then "taps"
            when :formula then "formulae"
            when :cask then "casks"
            when :command then "commands"
            else raise "Unsupported trust type: #{type}"
            end
            puts "Trusted #{label}:"
            values.each { |value| puts "  #{value}" }
            printed = true
          end

          puts "No trusted taps, formulae, casks or commands." unless printed
          return
        end

        args.named.each do |name|
          type, trust_name = Homebrew::Trust.target(name, type: selected_type)
          if type == :tap && Tap.fetch(trust_name).official?
            puts "Official tap #{trust_name} is always trusted."
            next
          end

          action = Homebrew::Trust.trust!(type, trust_name) ? "Trusted" : "Already trusted"

          puts "#{action} #{type}: #{trust_name}"
        end
      end

      private

      sig { returns(T.nilable(Symbol)) }
      def selected_type
        return :tap if args.tap?
        return :formula if args.formula?
        return :cask if args.cask?

        :command if args.command? || args.commands?
      end
    end
  end
end
