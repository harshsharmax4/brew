# typed: false
# frozen_string_literal: true

class InstallSteps < Formula
  # Sorbet type members are mutable by design and cannot be frozen.
  # rubocop:disable Style/MutableConstant
  Cache = type_template { { fixed: T::Hash[Symbol, T.untyped] } }
  # rubocop:enable Style/MutableConstant

  desc "Formula with structured install steps"
  homepage "https://brew.sh/install-steps"
  url "https://brew.sh/install-steps-1.0"

  post_install_steps do
    mkdir_p "log/install-steps"
    touch "install-steps/state"
    mv "move-source", "move-target"
    move_children "move-children-source", "move-children-target"
    ln_sf "move-target", "linked-target", source_base: :relative, uninstall: true
  end
end
