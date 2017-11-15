
require 'flor/pcore/iterator'


class Flor::Pro::Each < Flor::Macro::Iterator
  #
  # Each is a simplified version of [for-each](for_each.md).
  #
  # Calls a function for each element in the argument collection.
  #
  # When the "each" ends, `f.ret` is pointing back to the argument
  # collection.
  #
  # ```
  # set l []
  # each [ 0 1 2 3 4 5 6 7 ]
  #   pushr l (2 * elt) if elt % 2 == 0
  # ```
  # the var `l` will yield `[ 0, 4, 8, 12 ]` after the `each`
  # the field `ret` will yield `[ 0, 1, 2, 3, 4, 5, 6, 7 ]`.
  #
  # ```
  # set l []
  # each { a: 'A', b: 'B', c: 'C' }
  #   pushr l (+ key val idx)
  # ```
  # the var `l` will yield `[ 'aA0', 'bB1', 'cC2' ]` after the `each`
  #
  # ## see also
  #
  # for-each.

  name 'each'

  def rewrite_tree

    rewrite_iterator_tree('for-each')
  end
end

