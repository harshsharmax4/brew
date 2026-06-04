# typed: strict
# frozen_string_literal: true

require "env_config"
require "json"
require "tap"
require "utils"
require "utils/output"

module Homebrew
  class UntrustedTapError < RuntimeError; end

  module Trust
    extend Utils::Output::Mixin

    SETTING_KEYS = T.let({
      tap:     :trustedtaps,
      formula: :trustedformulae,
      cask:    :trustedcasks,
      command: :trustedcommands,
    }.freeze, T::Hash[Symbol, Symbol])
    private_constant :SETTING_KEYS

    sig { returns(Pathname) }
    def self.trust_file
      Pathname.new(ENV.fetch("HOMEBREW_USER_CONFIG_HOME"))/"trust.json"
    end

    sig { params(type: Symbol, name: String).returns(T::Boolean) }
    def self.trust!(type, name)
      key = setting_key(type)
      entries = trusted_entries(type)
      name = normalise_name(name)
      return false if entries.include?(name)

      store = trust_store
      store[key] = (entries + [name]).sort
      write_trust_store(store)
      true
    end

    sig { params(type: Symbol, name: String).returns(T::Boolean) }
    def self.untrust!(type, name)
      key = setting_key(type)
      entries = trusted_entries(type)
      name = normalise_name(name)
      return false unless entries.delete(name)

      store = trust_store
      if entries.empty?
        store.delete(key)
      else
        store[key] = entries.sort
      end
      write_trust_store(store)
      true
    end

    sig { params(names: T::Array[String], type: T.nilable(Symbol)).void }
    def self.trust_fully_qualified_items!(names, type: nil)
      names.each do |name|
        next if name.count("/") != 2

        tap_name = name.split("/").first(2).join("/")
        item_name = ::Utils.name_from_full_name(name)
        tap = Tap.fetch(tap_name)
        next if tap.official?

        types = if type == :formula
          tap.formula_files_by_name.key?(item_name) ? [:formula] : []
        elsif type == :cask
          tap.cask_files_by_name.key?(item_name) ? [:cask] : []
        elsif tap.formula_files_by_name.key?(item_name)
          [:formula]
        elsif tap.cask_files_by_name.key?(item_name)
          [:cask]
        else
          []
        end
        types.each { |item_type| trust!(item_type, "#{tap.name}/#{item_name}") }
      rescue Tap::InvalidNameError
        nil
      end
    end

    sig { params(type: Symbol).void }
    def self.clear!(type)
      store = trust_store
      store.delete(setting_key(type))
      write_trust_store(store)
    end

    sig { params(type: Symbol, name: String).returns(T::Boolean) }
    def self.trusted?(type, name)
      trusted_entries(type).include?(normalise_name(name))
    end

    sig { params(tap: T.untyped).returns(T::Boolean) }
    def self.trusted_tap?(tap)
      tap.official? || trusted?(:tap, tap.name)
    end

    sig { params(name: String, path: Pathname).void }
    def self.require_trusted_formula!(name, path)
      return if Homebrew::EnvConfig.no_require_tap_trust?
      return unless (tap = tap_from_path(path))
      return if trusted_tap?(tap)

      full_name = "#{tap.name}/#{::Utils.name_from_full_name(name)}"
      return if trusted?(:formula, full_name)
      return if explicitly_allowed?(:formula, full_name, tap)
      return unless Homebrew::EnvConfig.require_tap_trust?

      raise_untrusted!(:formula, full_name, tap)
    end

    sig { params(token: String, path: Pathname).void }
    def self.require_trusted_cask!(token, path)
      return if Homebrew::EnvConfig.no_require_tap_trust?
      return unless (tap = tap_from_path(path))
      return if trusted_tap?(tap)

      full_name = "#{tap.name}/#{::Utils.name_from_full_name(token)}"
      return if trusted?(:cask, full_name)
      return if explicitly_allowed?(:cask, full_name, tap)
      return unless Homebrew::EnvConfig.require_tap_trust?

      raise_untrusted!(:cask, full_name, tap)
    end

    sig { params(path: Pathname, command: T.nilable(String)).void }
    def self.require_trusted_command!(path, command = nil)
      return if Homebrew::EnvConfig.no_require_tap_trust?
      return unless (tap = tap_from_path(path))
      return if trusted_tap?(tap)

      full_name = "#{tap.name}/#{command || path.basename(path.extname).to_s.delete_prefix("brew-")}"
      return if trusted?(:command, full_name)
      return unless Homebrew::EnvConfig.require_tap_trust?

      raise_untrusted!(:command, full_name, tap)
    end

    sig { params(path: Pathname).returns(T::Boolean) }
    def self.trusted_formula_file?(path)
      trusted_file?(:formula, path)
    end

    sig { params(path: Pathname).returns(T::Boolean) }
    def self.trusted_cask_file?(path)
      trusted_file?(:cask, path)
    end

    sig { params(files: T::Array[Pathname]).returns(T::Array[Pathname]) }
    def self.trusted_formula_files(files)
      trusted_files(:formula, files)
    end

    sig { params(files: T::Array[Pathname]).returns(T::Array[Pathname]) }
    def self.trusted_cask_files(files)
      trusted_files(:cask, files)
    end

    sig { params(files: T::Array[Pathname]).returns(T::Array[Pathname]) }
    def self.trusted_command_files(files)
      trusted_files(:command, files)
    end

    sig { returns(T::Array[Tap]) }
    def self.untrusted_taps
      Tap.installed.reject(&:official?).reject { |tap| trusted?(:tap, tap.name) }.sort_by(&:name)
    end

    sig { returns(T::Array[Tap]) }
    def self.wholly_untrusted_taps
      untrusted_taps.reject do |tap|
        trusted_entry_prefix?(:formula, tap.name) ||
          trusted_entry_prefix?(:cask, tap.name) ||
          trusted_entry_prefix?(:command, tap.name)
      end
    end

    sig { params(type: Symbol).returns(String) }
    def self.setting_key(type)
      SETTING_KEYS.fetch(type).to_s
    end

    sig { params(type: Symbol).returns(T::Array[String]) }
    def self.trusted_entries(type)
      trust_store.fetch(setting_key(type), [])
    end

    sig { params(name: String).returns(String) }
    def self.normalise_name(name)
      name.downcase
    end

    sig { params(name: String, type: T.nilable(Symbol), include_existing: T::Boolean).returns([Symbol, String]) }
    def self.target(name, type: nil, include_existing: false)
      return [type, trust_name(type, name)] if type

      infer_target(name, include_existing:)
    end

    sig { params(name: String, include_existing: T::Boolean).returns([Symbol, String]) }
    def self.infer_target(name, include_existing:)
      return [:tap, trust_name(:tap, name)] if name.count("/") == 1

      tap_with_name = Tap.with_formula_name(name)
      unless tap_with_name
        raise UsageError,
              "Trust targets must be fully-qualified tap, formula, cask or command names."
      end

      tap, token = tap_with_name
      full_name = "#{tap.name}/#{token}"
      candidates = T.let([], T::Array[[Symbol, String]])
      candidates << [:formula, full_name] if tap.formula_files_by_name.key?(token)
      candidates << [:cask, full_name] if tap.cask_files_by_name.key?(token)
      candidates << [:command, full_name] if command_file?(tap, token)
      if include_existing
        candidates << [:formula, full_name] if trusted?(:formula, full_name)
        candidates << [:cask, full_name] if trusted?(:cask, full_name)
        candidates << [:command, full_name] if trusted?(:command, full_name)
      end
      candidates.uniq!

      return candidates.fetch(0) if candidates.one?

      raise UsageError, "No formula, cask or command found for #{name}." if candidates.empty?

      raise UsageError, "Ambiguous trust target #{name}. Use `--formula`, `--cask` or `--command`."
    end
    private_class_method :infer_target

    sig { params(type: Symbol, name: String).returns(String) }
    def self.trust_name(type, name)
      case type
      when :tap
        Tap.fetch(name).name
      when :formula
        tap, formula_name = fully_qualified_package_name(name, "Formulae")
        "#{tap.name}/#{formula_name}"
      when :cask
        tap, token = fully_qualified_package_name(name, "Casks")
        "#{tap.name}/#{token}"
      when :command
        tap, command_name = fully_qualified_package_name(name, "Commands")
        "#{tap.name}/#{command_name}"
      else
        raise UsageError, "Unsupported trust target type: #{type}"
      end
    rescue Tap::InvalidNameError => e
      raise UsageError, e.message
    end
    private_class_method :trust_name

    sig { params(name: String, noun: String).returns([Tap, String]) }
    def self.fully_qualified_package_name(name, noun)
      tap_with_name = Tap.with_formula_name(name)
      raise UsageError, "#{noun} must be fully-qualified as <user>/<tap>/<name>." unless tap_with_name

      tap_with_name
    end
    private_class_method :fully_qualified_package_name

    sig { params(tap: Tap, command_name: String).returns(T::Boolean) }
    def self.command_file?(tap, command_name)
      tap.command_files.any? { |path| path.basename(path.extname).to_s.delete_prefix("brew-") == command_name }
    end
    private_class_method :command_file?

    sig { returns(T::Hash[String, T::Array[String]]) }
    def self.trust_store
      trust_path = trust_file
      return {} unless trust_path.exist?

      parsed_store = JSON.parse(trust_path.read)
      return {} unless parsed_store.is_a?(Hash)

      parsed_store.transform_values { |entries| Array(entries).map { |entry| normalise_name(entry.to_s) } }
    rescue Errno::ENOENT, JSON::ParserError
      {}
    end
    private_class_method :trust_store

    sig { params(store: T::Hash[String, T::Array[String]]).void }
    def self.write_trust_store(store)
      trust_path = trust_file
      if store.empty?
        trust_path.unlink if trust_path.exist?
        return
      end

      trust_path.dirname.mkpath
      trust_path.atomic_write("#{JSON.pretty_generate(store)}\n")
      trust_path.chmod(0600)
    end
    private_class_method :write_trust_store

    sig { params(path: Pathname).returns(T.untyped) }
    def self.tap_from_path(path)
      Tap.from_path(path)
    end
    private_class_method :tap_from_path

    sig { params(type: Symbol, path: Pathname).returns(T::Boolean) }
    def self.trusted_file?(type, path)
      return true if Homebrew::EnvConfig.no_require_tap_trust?
      return true unless (tap = tap_from_path(path))
      return true if trusted_tap?(tap)

      name = path.basename(path.extname).to_s
      name = name.delete_prefix("brew-") if type == :command
      full_name = "#{tap.name}/#{name}"
      return true if trusted?(type, full_name)
      return true if explicitly_allowed?(type, full_name, tap)

      !Homebrew::EnvConfig.require_tap_trust?
    end
    private_class_method :trusted_file?

    sig { params(type: Symbol, full_name: String, tap: T.untyped).returns(T::Boolean) }
    def self.explicitly_allowed?(type, full_name, tap)
      return false if type == :command

      downcased_args = ARGV.map(&:downcase)
      downcased_full_name = full_name.downcase
      tap_name = tap.name.downcase
      downcased_args.include?(downcased_full_name) ||
        downcased_args.include?(tap_name) ||
        downcased_args.include?("--tap=#{tap_name}") ||
        downcased_args.each_cons(2).any? { |option, value| option == "--tap" && value == tap_name }
    end
    private_class_method :explicitly_allowed?

    sig { params(type: Symbol, files: T::Array[Pathname]).returns(T::Array[Pathname]) }
    def self.trusted_files(type, files)
      trusted_files = files.select { |file| trusted_file?(type, file) }
      return trusted_files unless Homebrew::EnvConfig.require_tap_trust?

      skipped_taps = (files - trusted_files).filter_map { |file| tap_from_path(file) }.uniq.sort_by(&:name)
      skipped_taps.each do |tap|
        opoo "Skipping #{tap.name} because it is not trusted. Run `brew trust #{tap.name}` to trust it."
      end

      trusted_files
    end
    private_class_method :trusted_files

    sig { params(type: Symbol, tap_name: String).returns(T::Boolean) }
    def self.trusted_entry_prefix?(type, tap_name)
      prefix = "#{tap_name}/"
      trusted_entries(type).any? { |entry| entry.start_with?(prefix) }
    end
    private_class_method :trusted_entry_prefix?

    sig { params(type: Symbol, name: String, tap: T.untyped).void }
    def self.raise_untrusted!(type, name, tap)
      raise UntrustedTapError, "Refusing to load #{type} #{name} from untrusted tap #{tap.name}.\n" \
                               "Run `brew trust --#{type} #{name}` or `brew trust #{tap.name}` to trust it."
    end
    private_class_method :raise_untrusted!
  end
end
