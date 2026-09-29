{ username }:
''
  // Managed by NixConfig: PC/SC access for this configured account only.
  polkit.addRule(function(action, subject) {
      if (subject.user === ${builtins.toJSON username} &&
          (action.id === "org.debian.pcsc-lite.access_pcsc" ||
           action.id === "org.debian.pcsc-lite.access_card")) {
          return polkit.Result.YES;
      }
  });
''
