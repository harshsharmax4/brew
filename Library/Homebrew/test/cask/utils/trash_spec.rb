# typed: false
# frozen_string_literal: true

require "cask/utils/trash"

RSpec.describe Cask::Utils::Trash do
  let(:klass) { Cask::Utils::Trash }

  describe "::trash" do
    let(:path) { Pathname("/tmp/example") }

    it "uses the Swift trash implementation on macOS" do
      expect(klass).to receive(:swift_trash)
        .with(path, command: nil)
        .and_return([[path.to_s], []])

      expect(klass.trash(path)).to eq([[path.to_s], []])
    end
  end

  describe "::swift_trash" do
    let(:path) { Pathname("/tmp/example") }
    let(:system_command_result) { instance_double(SystemCommand::Result, stdout: "#{path}\n") }

    it "uses the Swift helper on macOS" do
      expect(klass).to receive(:system_command)
        .with(HOMEBREW_LIBRARY_PATH/"cask/utils/trash.swift",
              args:         [path],
              print_stderr: Homebrew::EnvConfig.developer?)
        .and_return(system_command_result)

      expect(klass.send(:swift_trash, path)).to eq([[path.to_s], []])
    end
  end

  describe "::freedesktop_trash" do
    let(:deletion_time) { Time.local(2026, 4, 25, 13, 14, 15) }
    let(:xdg_data_home) { mktmpdir/"xdg-data" }
    let(:trash_path) { xdg_data_home/"Trash" }
    let(:files_path) { trash_path/"files" }
    let(:info_path) { trash_path/"info" }
    let(:path) { mktmpdir/"folder with spaces"/"example file.txt" }

    around do |example|
      old_xdg_data_home = ENV.fetch("XDG_DATA_HOME", nil)
      ENV["XDG_DATA_HOME"] = xdg_data_home.to_s
      example.run
    ensure
      ENV["XDG_DATA_HOME"] = old_xdg_data_home
    end

    it "moves files into the XDG trash and writes a trashinfo file" do
      path.dirname.mkpath
      path.write("example")
      allow(Time).to receive(:now).and_return(deletion_time)

      trashed, untrashable = klass.send(:freedesktop_trash, path)

      expect(path).not_to exist
      expect(trashed).to eq([path.to_s])
      expect(untrashable).to be_empty
      expect((files_path/"example file.txt").read).to eq("example")
      expect((info_path/"example file.txt.trashinfo").read).to eq(<<~EOS)
        [Trash Info]
        Path=#{URI::DEFAULT_PARSER.escape(path.to_s)}
        DeletionDate=2026-04-25T13:14:15
      EOS
    end
  end
end
