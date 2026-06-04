# typed: strict
# frozen_string_literal: true

require "extend/pathname"

RSpec.describe Pathname do
  describe ".write_env_script" do
    it "creates script with arguments" do
      mktmpdir do |tmpdir|
        (tmpdir/"wrapper_script").write_env_script tmpdir/"test", ["foo", "bar"], TEST: "baz"
        expect((tmpdir/"wrapper_script").read).to eq(<<~BASH)
          #!/bin/bash
          TEST="baz" exec "#{tmpdir}/test" foo bar "$@"
        BASH
      end
    end

    it "creates script without arguments" do
      mktmpdir do |tmpdir|
        (tmpdir/"wrapper_script").write_env_script "test", TEST: "bar", TEST2: tmpdir/"baz"
        expect((tmpdir/"wrapper_script").read).to eq(<<~BASH)
          #!/bin/bash
          TEST="bar" TEST2="#{tmpdir}/baz" exec "test"  "$@"
        BASH
      end
    end
  end
end
