# typed: strict
# frozen_string_literal: true

require "utils/path"

RSpec.describe Utils::Path do
  sig { returns(T.class_of(Utils::Path)) }
  let(:klass) { Utils::Path }

  describe "::child_of?" do
    it "recognizes a path as its own child" do
      expect(klass.child_of?("/foo/bar", "/foo/bar")).to be(true)
    end

    it "recognizes a path that is a child of the parent" do
      expect(klass.child_of?("/foo", "/foo/bar")).to be(true)
    end

    it "recognizes a path that is a grandchild of the parent" do
      expect(klass.child_of?("/foo", "/foo/bar/baz")).to be(true)
    end

    it "does not recognize a path that is not a child" do
      expect(klass.child_of?("/foo", "/bar/baz")).to be(false)
    end

    it "handles . and .. in paths correctly" do
      expect(klass.child_of?("/foo", "/foo/./bar")).to be(true)
      expect(klass.child_of?("/foo/bar", "/foo/../foo/bar/baz")).to be(true)
    end

    it "handles relative paths correctly" do
      expect(klass.child_of?("foo", "./bar/baz")).to be(false)
      expect(klass.child_of?("../foo", "./bar/baz/../../../foo/bar/baz")).to be(true)
    end
  end

  describe "::loadable_package_path?" do
    it "accepts formula paths under a symlinked cellar" do
      tmpdir = mktmpdir
      real_cellar = tmpdir/"real-cellar"
      symlink_cellar = tmpdir/"cellar"

      real_cellar.mkpath
      FileUtils.ln_s(real_cellar, symlink_cellar)
      stub_const("HOMEBREW_CELLAR", symlink_cellar)
      allow(Homebrew::EnvConfig).to receive(:forbid_packages_from_paths?).and_return(true)

      formula_path = real_cellar/"poshtui/0.16/.brew/poshtui.rb"
      formula_path.dirname.mkpath
      formula_path.write <<~RUBY
        class Poshtui < Formula; end
      RUBY

      expect(klass.loadable_package_path?(formula_path, :formula)).to be(true)
    end
  end
end
