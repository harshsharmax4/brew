# typed: strict
# frozen_string_literal: true

RSpec.describe Cask::CaskLoader::FromContentLoader do
  sig { returns(T.class_of(Cask::CaskLoader::FromContentLoader)) }
  let(:klass) { Cask::CaskLoader::FromContentLoader }

  describe "::try_new" do
    it "returns a loader for Casks specified with `cask \"token\" do … end`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask "token" do
        end
      RUBY
    end

    it "returns a loader for Casks specified with `cask \"token\" do; end`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask "token" do; end
      RUBY
    end

    it "returns a loader for Casks specified with `cask 'token' do … end`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask 'token' do
        end
      RUBY
    end

    it "returns a loader for Casks specified with `cask 'token' do; end`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask 'token' do; end
      RUBY
    end

    it "returns a loader for Casks specified with `cask(\"token\") { … }`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask("token") {
        }
      RUBY
    end

    it "returns a loader for Casks specified with `cask(\"token\") {}`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask("token") {}
      RUBY
    end

    it "returns a loader for Casks specified with `cask('token') { … }`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask('token') {
        }
      RUBY
    end

    it "returns a loader for Casks specified with `cask('token') {}`" do
      expect(klass.try_new(<<~RUBY)).not_to be_nil
        cask('token') {}
      RUBY
    end
  end
end
