# typed: strict
# frozen_string_literal: true

require "extend/cachable"
require "api/download"
require "formula_stub"

module Homebrew
  module API
    # Helper functions for using the JSON internal API.
    module Internal
      extend Cachable

      private_class_method :cache

      sig { returns(String) }
      def self.endpoint
        "internal/formula.#{SimulateSystem.current_tag}.jws.json"
      end

      sig { params(name: String).returns(T::Hash[String, T.untyped]) }
      def self.formula(name)
        tag = Utils::Bottles.tag
        formula_stub = Homebrew::FormulaStub.from_array formula_stub(name)

        bottle_specification = BottleSpecification.new
        bottle_specification.tap = Homebrew::DEFAULT_REPOSITORY
        bottle_specification.rebuild formula_stub.rebuild
        bottle_specification.sha256 tag.to_sym => formula_stub.sha256

        bottle = Bottle.new(formula_stub, bottle_specification, tag)
        bottle_manifest_resource = T.must(bottle.github_packages_manifest_resource)

        begin
          bottle_manifest_resource.fetch
          bottle_manifest_resource.formula_json
        rescue Resource::BottleManifest::Error
          opoo "Falling back to API fetch for #{name}"
          Homebrew::API.fetch "formula/#{name}.json"
        end
      end

      sig { returns(Pathname) }
      def self.cached_json_file_path
        HOMEBREW_CACHE_API/endpoint
      end

      sig { returns(T::Boolean) }
      def self.download_and_cache_data!
        json_formula_stubs, updated = Homebrew::API.fetch_json_api_file endpoint
        cache["formula_stubs"] = {}
        cache["all_formula_stubs"] = json_formula_stubs
        updated
      end
      private_class_method :download_and_cache_data!

      sig { params(name: String).returns([String, String, Integer, T.nilable(String)]) }
      def self.formula_stub(name)
        download_and_cache_data! unless cache.key?("all_formula_stubs")

        return cache["formula_stubs"][name] if cache["formula_stubs"].key?(name)

        cache["all_formula_stubs"].find do |stub|
          next false if stub["name"] != name

          cache["formula_stubs"][name] = stub
          true
        end
      end
    end
  end
end
