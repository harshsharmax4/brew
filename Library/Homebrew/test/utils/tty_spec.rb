# typed: strict
# frozen_string_literal: true

RSpec.describe Tty do
  sig { returns(T.class_of(Tty)) }
  let(:klass) { Tty }

  describe "::strip_ansi" do
    it "removes ANSI escape codes from a string" do
      expect(klass.strip_ansi("\033[36;7mhello\033[0m")).to eq("hello")
    end
  end

  describe "::width" do
    specify do
      expect(klass.width).to be_a(Integer)
      expect(klass.width).to be >= 0
    end
  end

  describe "::truncate" do
    it "truncates the text to the terminal width, minus 4, to account for '==> '" do
      allow(klass).to receive(:width).and_return(15)

      expect(klass.truncate("foobar something very long")).to eq("foobar some")
      expect(klass.truncate("truncate")).to eq("truncate")
    end

    it "doesn't truncate the text if the terminal is unsupported, i.e. the width is 0" do
      allow(klass).to receive(:width).and_return(0)
      expect(klass.truncate("foobar something very long")).to eq("foobar something very long")
    end
  end

  context "when $stdout is not a TTY" do
    before do
      allow($stdout).to receive(:tty?).and_return(false)
    end

    it "returns an empty string for all colors" do
      expect(klass.to_s).to eq("")
      expect(klass.red.to_s).to eq("")
      expect(klass.green.to_s).to eq("")
      expect(klass.yellow.to_s).to eq("")
      expect(klass.blue.to_s).to eq("")
      expect(klass.magenta.to_s).to eq("")
      expect(klass.cyan.to_s).to eq("")
      expect(klass.default.to_s).to eq("")
    end
  end

  context "when $stdout is a TTY" do
    before do
      allow($stdout).to receive(:tty?).and_return(true)
    end

    it "returns ANSI escape codes for colors" do
      expect(klass.to_s).to eq("")
      expect(klass.red.to_s).to eq("\033[31m")
      expect(klass.green.to_s).to eq("\033[32m")
      expect(klass.yellow.to_s).to eq("\033[33m")
      expect(klass.blue.to_s).to eq("\033[34m")
      expect(klass.magenta.to_s).to eq("\033[35m")
      expect(klass.cyan.to_s).to eq("\033[36m")
      expect(klass.default.to_s).to eq("\033[39m")
    end

    it "returns an empty string for all colors when HOMEBREW_NO_COLOR is set" do
      ENV["HOMEBREW_NO_COLOR"] = "1"
      expect(klass.to_s).to eq("")
      expect(klass.red.to_s).to eq("")
      expect(klass.green.to_s).to eq("")
      expect(klass.yellow.to_s).to eq("")
      expect(klass.blue.to_s).to eq("")
      expect(klass.magenta.to_s).to eq("")
      expect(klass.cyan.to_s).to eq("")
      expect(klass.default.to_s).to eq("")
    end
  end
end
