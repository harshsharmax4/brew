# typed: strict
# frozen_string_literal: true

# Eagerly initialises {Pathname}'s lazy memoised ivars so every instance
# shares one object shape, avoiding Ruby's shape-variation warning.
#
# Any new `@x ||= ...` ivar added to {Pathname} or its mixed-in extensions
# must also be added to `#initialize` below to keep the shape stable.
module EagerInitializeExtension
  extend T::Helpers

  requires_ancestor { Pathname }

  sig { params(args: T.untyped).void }
  def initialize(*args)
    @magic_number = T.let(nil, T.nilable(String))
    @file_type = T.let(nil, T.nilable(String))
    @zipinfo = T.let(nil, T.nilable(T::Array[String]))
    @which_install_info = T.let(nil, T.nilable(String))
    @disk_usage = T.let(nil, T.nilable(Integer))
    @file_count = T.let(nil, T.nilable(Integer))
    super
  end
end
