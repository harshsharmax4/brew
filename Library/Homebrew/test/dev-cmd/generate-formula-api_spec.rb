# typed: strict
# frozen_string_literal: true

require "cmd/shared_examples/args_parse"
require "dev-cmd/generate-formula-api"

RSpec.describe Homebrew::DevCmd::GenerateFormulaApi do
  it_behaves_like "parseable arguments"

  it "writes formula executables to generated formula data" do
    core_tap = instance_double(CoreTap, installed?: true, name: "homebrew/core", formula_names: ["foo"],
                                        alias_table: {}, formula_renames: {}, git_head: "formula-head",
                                        tap_migrations: {})
    bottle_tag = Utils::Bottles::Tag.from_symbol(:arm64_sonoma)

    allow(CoreTap).to receive(:instance).and_return(core_tap)
    allow(Formulary).to receive(:enable_factory_cache!)
    allow(Formula).to receive(:generating_hash!)
    allow(Formulary).to receive(:factory).with("foo").and_return(
      instance_double(Formula, name: "foo", to_hash_with_variations: { "name" => "foo" }),
    )
    allow(Homebrew::API).to receive(:download_executables_file_from_github_packages!) do |target|
      target.write "foo(1.0.0):foo-tool food\n"
      true
    end
    allow(Homebrew::API::Formula::FormulaStructGenerator).to receive(:generate_formula_struct_hash)
      .with({ "name" => "foo", "executables" => ["foo-tool", "food"] }, bottle_tag:)
      .and_return(
        instance_double(
          Homebrew::API::FormulaStruct,
          serialize: { "name" => "foo", "executables" => ["foo-tool", "food"] },
        ),
      )
    stub_const("OnSystem::VALID_OS_ARCH_TAGS", [bottle_tag])

    Dir.mktmpdir do |tmpdir|
      path = Pathname.new(tmpdir)
      path.cd { Homebrew::DevCmd::GenerateFormulaApi.new([]).run }

      expect(JSON.parse((path/"_data/formula/foo.json").read)["executables"]).to eq(["foo-tool", "food"])
      expect(JSON.parse((path/"api/internal/formula.arm64_sonoma.json").read)
        .dig("formulae", "foo", "executables")).to eq(["foo-tool", "food"])
    end
  end
end
