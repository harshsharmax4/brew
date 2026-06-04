# typed: true
# frozen_string_literal: true

require "locale"

RSpec.describe Locale do
  let(:klass) { Locale }

  describe "::parse" do
    it "parses a string in the correct format" do
      expect(klass.parse("zh")).to eql(klass.new("zh", nil, nil))
      expect(klass.parse("zh-CN")).to eql(klass.new("zh", nil, "CN"))
      expect(klass.parse("zh-Hans")).to eql(klass.new("zh", "Hans", nil))
      expect(klass.parse("zh-Hans-CN")).to eql(klass.new("zh", "Hans", "CN"))
    end

    it "correctly parses a string with a UN M.49 region code" do
      expect(klass.parse("es-419")).to eql(klass.new("es", nil, "419"))
    end

    describe "raises a ParserError when given" do
      it "an empty string" do
        expect { klass.parse("") }.to raise_error(Locale::ParserError)
      end

      it "a string in a wrong format" do
        expect { klass.parse("zh-CN-Hans") }.to raise_error(Locale::ParserError)
        expect { klass.parse("zh_CN_Hans") }.to raise_error(Locale::ParserError)
        expect { klass.parse("zhCNHans") }.to raise_error(Locale::ParserError)
        expect { klass.parse("zh-CN_Hans") }.to raise_error(Locale::ParserError)
        expect { klass.parse("zhCN") }.to raise_error(Locale::ParserError)
        expect { klass.parse("zh_Hans") }.to raise_error(Locale::ParserError)
        expect { klass.parse("zh-") }.to raise_error(Locale::ParserError)
        expect { klass.parse("ZH-CN") }.to raise_error(Locale::ParserError)
        expect { klass.parse("zh-cn") }.to raise_error(Locale::ParserError)
      end
    end
  end

  describe "::new" do
    it "raises an ArgumentError when all arguments are nil" do
      expect { klass.new(nil, nil, nil) }.to raise_error(ArgumentError)
    end

    it "raises a ParserError when one of the arguments does not match the locale format" do
      expect { klass.new("ZH", nil, nil) }.to raise_error(Locale::ParserError)
      expect { klass.new(nil, "hans", nil) }.to raise_error(Locale::ParserError)
      expect { klass.new(nil, nil, "cn") }.to raise_error(Locale::ParserError)
    end
  end

  describe "#include?" do
    subject(:locale) { klass.new("zh", "Hans", "CN") }

    specify(:aggregate_failures) do
      expect(locale).to include("zh")
      expect(locale).to include("zh-CN")
      expect(locale).to include("CN")
      expect(locale).to include("Hans-CN")
      expect(locale).to include("Hans")
      expect(locale).to include("zh-Hans-CN")
    end
  end

  describe "#eql?" do
    subject(:locale) { klass.new("zh", "Hans", "CN") }

    context "when all parts match" do
      specify(:aggregate_failures) do
        expect(locale).to eql("zh-Hans-CN")
        expect(locale).to eql(klass.new("zh", "Hans", "CN"))
      end
    end

    context "when only some parts match" do
      specify(:aggregate_failures) do
        expect(locale).not_to eql("zh")
        expect(locale).not_to eql("zh-CN")
        expect(locale).not_to eql("CN")
        expect(locale).not_to eql("Hans-CN")
        expect(locale).not_to eql("Hans")
      end
    end

    it "does not raise if 'other' cannot be parsed" do
      expect { locale.eql?("zh_CN_Hans") }.not_to raise_error
      expect(locale.eql?("zh_CN_Hans")).to be false
    end
  end

  describe "#detect" do
    let(:locale_groups) { [["zh"], ["zh-TW"]] }

    it "finds best matching language code, independent of order" do
      expect(klass.new("zh", nil, "TW").detect(locale_groups)).to eql(["zh-TW"])
      expect(klass.new("zh", nil, "TW").detect(locale_groups.reverse)).to eql(["zh-TW"])
      expect(klass.new("zh", "Hans", "CN").detect(locale_groups)).to eql(["zh"])
    end
  end
end
