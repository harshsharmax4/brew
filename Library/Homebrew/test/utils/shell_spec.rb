# typed: true
# frozen_string_literal: true

require "utils/shell"

RSpec.describe Utils::Shell do
  let(:klass) { Utils::Shell }

  describe "::profile" do
    it "returns ~/.profile by default" do
      ENV["SHELL"] = "/bin/another_shell"
      expect(klass.profile).to eq("~/.profile")
    end

    it "returns ~/.profile for sh" do
      ENV["SHELL"] = "/bin/sh"
      expect(klass.profile).to eq("~/.profile")
    end

    it "returns ~/.profile for Bash" do
      ENV["SHELL"] = "/bin/bash"
      expect(klass.profile).to eq("~/.profile")
    end

    it "returns /tmp/.zshrc for Zsh if ZDOTDIR is /tmp" do
      ENV["SHELL"] = "/bin/zsh"
      ENV["HOMEBREW_ZDOTDIR"] = "/tmp"
      expect(klass.profile).to eq("/tmp/.zshrc")
    end

    it "returns ~/.zshrc for Zsh" do
      ENV["SHELL"] = "/bin/zsh"
      ENV["HOMEBREW_ZDOTDIR"] = nil
      expect(klass.profile).to eq("~/.zshrc")
    end

    it "returns ~/.kshrc for Ksh" do
      ENV["SHELL"] = "/bin/ksh"
      expect(klass.profile).to eq("~/.kshrc")
    end

    it "returns ~/.config/powershell/Microsoft.PowerShell_profile.ps1 for PowerShell" do
      ENV["SHELL"] = "/usr/bin/pwsh"
      expect(klass.profile).to eq("~/.config/powershell/Microsoft.PowerShell_profile.ps1")
    end
  end

  describe "::from_path" do
    it "supports a raw command name" do
      expect(klass.from_path("bash")).to eq(:bash)
    end

    it "supports full paths" do
      expect(klass.from_path("/bin/bash")).to eq(:bash)
    end

    it "supports versions" do
      expect(klass.from_path("zsh-5.2")).to eq(:zsh)
    end

    it "strips newlines" do
      expect(klass.from_path("zsh-5.2\n")).to eq(:zsh)
    end

    it "returns nil when input is invalid" do
      expect(klass.from_path("")).to be_nil
      expect(klass.from_path("@@@@@@")).to be_nil
      expect(klass.from_path("invalid_shell-4.2")).to be_nil
    end
  end

  specify "::sh_quote" do
    expect(klass.send(:sh_quote, "")).to eq("''")
    expect(klass.send(:sh_quote, "\\")).to eq("\\\\")
    expect(klass.send(:sh_quote, "\n")).to eq("'\n'")
    expect(klass.send(:sh_quote, "$")).to eq("\\$")
    expect(klass.send(:sh_quote, "word")).to eq("word")
  end

  specify "::csh_quote" do
    expect(klass.send(:csh_quote, "")).to eq("''")
    expect(klass.send(:csh_quote, "\\")).to eq("\\\\")
    # NOTE: This test is different than for `sh`.
    expect(klass.send(:csh_quote, "\n")).to eq("'\\\n'")
    expect(klass.send(:csh_quote, "$")).to eq("\\$")
    expect(klass.send(:csh_quote, "word")).to eq("word")
  end

  describe "::prepend_path_in_profile" do
    let(:path) { "/my/path" }

    it "supports tcsh" do
      ENV["SHELL"] = "/bin/tcsh"
      expect(klass.prepend_path_in_profile(path))
        .to eq("echo 'setenv PATH #{path}:$PATH' >> #{klass.profile}")
    end

    it "supports Bash" do
      ENV["SHELL"] = "/bin/bash"
      expect(klass.prepend_path_in_profile(path))
        .to eq("echo 'export PATH=\"#{path}:$PATH\"' >> #{klass.profile}")
    end

    it "supports fish" do
      ENV["SHELL"] = "/usr/local/bin/fish"
      ENV["fish_user_paths"] = "/some/path"
      expect(klass.prepend_path_in_profile(path))
        .to eq("fish_add_path #{path}")
    end
  end

  describe "::shell_with_prompt" do
    let(:home) { HOMEBREW_TEMP }
    let(:notice) { "" }
    let(:prompt) { "test" }
    let(:path) { "/some/path" }

    it "returns zsh-specific prompt configuration" do
      preferred_path = "/bin/zsh"
      ENV["SHELL"] = preferred_path
      ENV["PATH"] = path
      zdotdir = "#{HOMEBREW_TEMP}/brew-zsh-prompt-#{Process.euid}"
      expect(klass.shell_with_prompt(prompt, preferred_path:, notice:, home:)).to eq \
        "BREW_PROMPT_PATH=\"#{path}\" BREW_PROMPT_TYPE=\"#{prompt}\" ZDOTDIR=\"#{zdotdir}\" #{preferred_path}"
    end

    it "returns bash-specific prompt configuration" do
      preferred_path = "/bin/bash"
      ENV["SHELL"] = "/bin/bash"
      ENV["PATH"] = path
      rcfile = "#{HOMEBREW_LIBRARY_PATH}/utils/bash/brew-sh-prompt-bashrc.bash"
      expect(klass.shell_with_prompt(prompt, preferred_path:, notice:, home:)).to eq \
        "BREW_PROMPT_PATH=\"#{path}\" BREW_PROMPT_TYPE=\"#{prompt}\" #{preferred_path} --rcfile \"#{rcfile}\""
    end

    it "returns generic shell prompt configuration" do
      preferred_path = "/bin/dash"
      ENV["SHELL"] = preferred_path
      expect(klass.shell_with_prompt(prompt, preferred_path:, notice:, home:)).to eq \
        "PS1=\"\\[\\033[1;32m\\]#{prompt} \\[\\033[1;31m\\]\\w \\[\\033[1;34m\\]$\\[\\033[0m\\] \" #{preferred_path}"
    end

    it "outputs notice when provided" do
      notice = "Test Notice"
      expect { klass.shell_with_prompt("test", preferred_path: "/bin/bash", notice: notice) }
        .to output("#{notice}\n").to_stdout
    end
  end
end
