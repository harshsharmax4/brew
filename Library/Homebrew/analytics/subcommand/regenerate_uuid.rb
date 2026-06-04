# typed: strict
# frozen_string_literal: true

require "abstract_subcommand"
require "utils/analytics"

module Homebrew
  module Cmd
    class Analytics < Homebrew::AbstractCommand
      class RegenerateUuidSubcommand < Homebrew::AbstractSubcommand
        subcommand_args do
          usage_banner <<~EOS
            `brew analytics regenerate-uuid`:
            Delete Homebrew's legacy analytics UUID.
          EOS
          named_args :none
        end

        sig { override.void }
        def run
          # odeprecated: remove in 5.2.0.
          Utils::Analytics.delete_uuid!
          opoo "Homebrew no longer uses an analytics UUID so this has been deleted!"
          puts "brew analytics regenerate-uuid is no longer necessary."
        end
      end
    end
  end
end
