# typed: false
# frozen_string_literal: true

require "manpages"

RSpec.describe Homebrew::Manpages do
  before { stub_const("Cmd", Class.new(Homebrew::AbstractCommand)) }

  def subcommand_parser
    Homebrew::CLI::Parser.new(Cmd) do
      usage_banner "`test` [<subcommand>]"
      description "Test command."
      switch "--global"

      subcommand "install", default: true do
        usage_banner <<~EOS
          `test install`:
          Install dependencies.
        EOS
        switch "--force"
        named_args :none
      end

      subcommand "info" do
        usage_banner <<~EOS
          `test info` <service>:
          Show service information.
        EOS
        switch "--json"
        named_args :service, min: 1
      end
    end
  end

  it "lists options under the root command and matching subcommands", :aggregate_failures do
    root_section, install_and_info_sections = Homebrew::Manpages
                                              .cmd_parser_manpage_lines(subcommand_parser)
                                              .join
                                              .split("`test install`:")
    install_section, info_section = install_and_info_sections.split("`test info` <service>:")

    expect(root_section).to include("`--global`")
    expect(root_section).not_to include("`--force`")
    expect(root_section).not_to include("`--json`")
    expect(install_section).to include("`--force`")
    expect(install_section).not_to include("`--json`")
    expect(info_section).to include("`--json`")
    expect(info_section).not_to include("`--force`")
  end
end
