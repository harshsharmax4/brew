# typed: strict
# frozen_string_literal: true

require "language/python"

RSpec.describe Language::Python, :needs_python do
  sig { returns(T.class_of(Language::Python)) }
  let(:klass) { Language::Python }

  describe "#major_minor_version" do
    it "returns a Version for Python 2" do
      expect(klass).to receive(:major_minor_version).and_return(Version)
      klass.major_minor_version("python")
    end
  end

  describe "#site_packages" do
    it "gives a different location between PyPy and Python 2" do
      expect(klass.site_packages("python")).not_to eql(klass.site_packages("pypy"))
    end
  end

  describe "#homebrew_site_packages" do
    it "returns the Homebrew site packages location" do
      expect(klass).to receive(:site_packages).and_return(Pathname)
      klass.site_packages("python")
    end
  end

  describe "#user_site_packages" do
    it "can determine user site packages location" do
      expect(klass).to receive(:user_site_packages).and_return(Pathname)
      klass.user_site_packages("python")
    end
  end
end
