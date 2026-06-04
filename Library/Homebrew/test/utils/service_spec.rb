# typed: strict
# frozen_string_literal: true

require "utils/service"

RSpec.describe Utils::Service do
  sig { returns(T.class_of(Utils::Service)) }
  let(:klass) { Utils::Service }

  describe "::systemd_quote" do
    it "quotes empty strings correctly" do
      expect(klass.systemd_quote("")).to eq '""'
    end

    it "quotes strings with special characters escaped correctly" do
      expect(klass.systemd_quote("\a\b\f\n\r\t\v\\"))
        .to eq '"\\a\\b\\f\\n\\r\\t\\v\\\\"'
      expect(klass.systemd_quote("\"' ")).to eq "\"\\\"' \""
    end

    it "does not escape characters that do not need escaping" do
      expect(klass.systemd_quote("daemon off;")).to eq '"daemon off;"'
      expect(klass.systemd_quote("--timeout=3")).to eq '"--timeout=3"'
      expect(klass.systemd_quote("--answer=foo bar"))
        .to eq '"--answer=foo bar"'
    end
  end
end
