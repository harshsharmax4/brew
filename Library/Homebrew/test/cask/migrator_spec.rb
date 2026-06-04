# typed: false
# frozen_string_literal: true

require "cask/migrator"

RSpec.describe Cask::Migrator do
  let(:klass) { Cask::Migrator }

  describe ".migrate_if_needed" do
    let(:new_cask) do
      instance_double(
        Cask::Cask,
        old_tokens:         ["old-token"],
        installed_caskfile:,
        token:              new_token,
      )
    end

    context "when the installed token matches the current token" do
      let(:installed_caskfile) { Pathname("/tmp/Casks/docker-desktop.rb") }
      let(:new_token) { "docker-desktop" }

      it "returns without loading or migrating" do
        expect(Cask::Cask).not_to receive(:new)
        expect(klass).not_to receive(:new)

        klass.migrate_if_needed(new_cask)
      end
    end

    context "when the installed token differs from the current token" do
      let(:installed_caskfile) { Pathname("/tmp/Casks/old-token.rb") }
      let(:new_token) { "new-token" }

      it "migrates using the installed token from the caskfile path" do
        old_cask = instance_double(Cask::Cask)
        migrator = instance_double(klass)

        expect(Cask::Cask).to receive(:new).with("old-token").and_return(old_cask)
        expect(klass).to receive(:new).with(old_cask, new_cask).and_return(migrator)
        expect(migrator).to receive(:migrate).with(dry_run: false)

        klass.migrate_if_needed(new_cask)
      end
    end
  end

  describe "#migrate" do
    let(:old_caskroom_path) { Pathname("/tmp/Caskroom/old-token") }
    let(:new_caskroom_path) { Pathname("/tmp/Caskroom/new-token") }
    let(:old_caskfile) { old_caskroom_path/".metadata/1.0/20240101000000/Casks/old-token.rb" }
    let(:new_caskfile) { new_caskroom_path/".metadata/1.0/20240101000000/Casks/new-token.rb" }
    let(:old_pin_path) { Pathname("/tmp/pinned_casks/old-token") }
    let(:new_pin_path) { Pathname("/tmp/pinned_casks/new-token") }
    let(:old_cask) do
      instance_double(
        Cask::Cask,
        token:              "old-token",
        caskroom_path:      old_caskroom_path,
        installed_caskfile: old_caskfile,
        pin_path:           old_pin_path,
        pinned_version:     "1.0",
      )
    end
    let(:new_cask) do
      instance_double(
        Cask::Cask,
        token:         "new-token",
        caskroom_path: new_caskroom_path,
        installed?:    true,
        pin_path:      new_pin_path,
      )
    end

    before do
      allow(old_pin_path).to receive(:symlink?).and_return(true)
      allow(FileUtils).to receive(:cp_r).with(old_caskroom_path, new_caskroom_path)
      allow(FileUtils).to receive(:mv).with(new_caskroom_path/old_caskfile.relative_path_from(old_caskroom_path),
                                            new_caskfile)
      allow(FileUtils).to receive(:rm_r).with(old_caskroom_path)
      allow(FileUtils).to receive(:ln_s).with(new_caskroom_path.basename, old_caskroom_path)
      allow(klass).to receive(:replace_caskfile_token).with(new_caskfile, "old-token", "new-token")
    end

    it "moves a cask pin to the new token" do
      expect(old_cask).to receive(:unpin)
      expect(new_pin_path).to receive(:make_relative_symlink).with(new_caskroom_path/"1.0")

      klass.new(old_cask, new_cask).migrate
    end

    it "prints relative cask pin targets in dry run" do
      expect do
        klass.new(old_cask, new_cask).migrate(dry_run: true)
      end.to output(%r{ln -s ../Caskroom/new-token/1\.0 /tmp/pinned_casks/new-token}).to_stdout
    end

    it "does not remove the old cask pin when creating the new pin fails" do
      allow(new_pin_path).to receive(:make_relative_symlink).and_raise(RuntimeError, "failed")
      expect(old_cask).not_to receive(:unpin)

      expect do
        klass.new(old_cask, new_cask).migrate
      end.to output(/Failed to migrate cask pin from old-token to new-token: failed/).to_stderr
    end
  end
end
