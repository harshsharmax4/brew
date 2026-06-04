# typed: true
# frozen_string_literal: true

require "os/linux/libstdcxx"

RSpec.describe OS::Linux::Libstdcxx do
  let(:klass) { OS::Linux::Libstdcxx }

  describe "::below_ci_version?" do
    it "returns false when system version matches CI version" do
      allow(klass).to receive(:system_version).and_return(Version.new(OS::LINUX_LIBSTDCXX_CI_VERSION))
      expect(klass.below_ci_version?).to be false
    end

    it "returns true when system version cannot be detected" do
      allow(klass).to receive(:system_version).and_return(Version::NULL)
      expect(klass.below_ci_version?).to be true
    end
  end

  describe "::system_version" do
    let(:tmpdir) { mktmpdir }
    let(:libstdcxx) { tmpdir/OS::Linux::Libstdcxx::SONAME }
    let(:soversion) { Version.new(OS::Linux::Libstdcxx::SOVERSION.to_s) }

    before do
      tmpdir.mkpath
      klass.instance_variable_set(:@system_version, nil)
      allow(klass).to receive(:system_path).and_return(libstdcxx)
    end

    after do
      FileUtils.rm_rf(tmpdir)
    end

    it "returns NULL when unable to find system path" do
      allow(klass).to receive(:system_path).and_return(nil)
      expect(klass.system_version).to be Version::NULL
    end

    it "returns full version from filename" do
      full_version = Version.new("#{soversion}.0.999")
      libstdcxx_real = libstdcxx.sub_ext(".#{full_version}")
      FileUtils.touch libstdcxx_real
      FileUtils.ln_s libstdcxx_real, libstdcxx
      expect(klass.system_version).to eq full_version
    end

    it "returns major version when non-standard libstdc++ filename without full version" do
      FileUtils.touch libstdcxx
      expect(klass.system_version).to eq soversion
    end

    it "returns major version when non-standard libstdc++ filename with unexpected realpath" do
      libstdcxx_real = tmpdir/"libstdc++.so.real"
      FileUtils.touch libstdcxx_real
      FileUtils.ln_s libstdcxx_real, libstdcxx
      expect(klass.system_version).to eq soversion
    end
  end
end
