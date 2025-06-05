# typed: strict
# frozen_string_literal: true

require "pkg_version"

module Homebrew
  # A stub for a formula, with only the information needed to fetch the bottle manifest.
  class FormulaStub < T::Struct
    const :name, String
    const :pkg_version, PkgVersion
    const :rebuild, Integer
    const :sha256, T.nilable(String)

    sig { params(array: [String, String, Integer, T.nilable(String)]).returns(FormulaStub) }
    def self.from_array(array)
      new(
        name:        array[0],
        pkg_version: PkgVersion.parse(array[1]),
        rebuild:     array[2],
        sha256:      array[3],
      )
    end
  end
end
