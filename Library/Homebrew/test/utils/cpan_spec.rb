# typed: true
# frozen_string_literal: true

require "utils/cpan"

RSpec.describe CPAN do
  let(:klass) { CPAN }

  let(:cpan_package_url) do
    "https://cpan.metacpan.org/authors/id/P/PE/PEVANS/Scalar-List-Utils-1.68.tar.gz"
  end
  let(:cpan_tgz_url) do
    "https://cpan.metacpan.org/authors/id/S/ST/STBEY/Example-Module-1.23.tgz"
  end
  let(:non_cpan_package_url) do
    "https://github.com/example/package/archive/v1.0.0.tar.gz"
  end

  describe CPAN::Package do
    let(:klass) { CPAN::Package }

    let(:package_from_cpan_url) { klass.new("Scalar::Util", cpan_package_url) }
    let(:package_from_tgz_url) { klass.new("Example::Module", cpan_tgz_url) }
    let(:package_from_non_cpan_url) { klass.new("SomePackage", non_cpan_package_url) }

    describe "initialize" do
      specify do
        expect(package_from_cpan_url.name).to eq "Scalar::Util"
        expect(package_from_cpan_url.current_version).to eq "1.68"
        expect(package_from_tgz_url.current_version).to eq "1.23"
      end
    end

    describe ".valid_cpan_package?" do
      specify do
        expect(package_from_cpan_url.valid_cpan_package?).to be true
        expect(package_from_non_cpan_url.valid_cpan_package?).to be false
      end
    end

    describe ".to_s" do
      it "returns resource name" do
        expect(package_from_cpan_url.to_s).to eq "Scalar::Util"
      end
    end
  end
end
