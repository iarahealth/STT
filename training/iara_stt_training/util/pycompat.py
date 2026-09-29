"""Shims for libraries that still expect Python 3.9 collection aliases."""

import collections
import collections.abc

for _name in ("Mapping", "MutableMapping", "Sequence", "Iterable"):
    if not hasattr(collections, _name):
        setattr(collections, _name, getattr(collections.abc, _name))
