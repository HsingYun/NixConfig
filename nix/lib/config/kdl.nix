# Constructors for Home Manager's KDL representation. These return ordinary
# attributes and lists; option merging and serialization remain upstream-owned.
{
  children = nodes: { _children = nodes; };
  props = properties: { _props = properties; };
  node =
    name: args: body:
    assert builtins.isAttrs body && !(body ? _args);
    {
      ${name} = body // (if args == [ ] then { } else { _args = args; });
    };
  # Serialization requires Home Manager's library; constructors are independent
  # of module evaluation and can also be used in host definitions.
  render =
    { lib }:
    lib.hm.generators.toKDL {
      escapeBackslashes = true;
      escapeTabs = true;
    };
}
