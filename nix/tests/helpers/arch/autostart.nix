{ pkgs }:
pkgs.runCommand "native-input-autostart-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  python3 - ${../../../assets/helpers}/arch/autostart.py <<'PY'
  import importlib.util, pathlib, sys, tempfile
  sys.path.insert(0, str(pathlib.Path(sys.argv[1]).parent))
  spec = importlib.util.spec_from_file_location('autostart', sys.argv[1])
  helper = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(helper)
  with tempfile.TemporaryDirectory() as tmp:
      base = pathlib.Path(tmp)
      dest, state = base / 'autostart/fcitx.desktop', base / 'state/owned'
      helper.suppress(dest, state, False)
      assert not dest.exists() and not state.exists()
      helper.suppress(dest, state, True)
      stamp = dest.stat().st_mtime_ns
      helper.suppress(dest, state, False)
      helper.suppress(dest, state, True)
      assert dest.stat().st_mtime_ns == stamp
      assert 'Hidden=true' in dest.read_text()
      dest.write_text('user edit')
      for enabled in [False, True]:
          try:
              helper.suppress(dest, state, enabled)
          except RuntimeError:
              pass
          else:
              raise AssertionError('user edit overwritten')
      assert dest.read_text() == 'user edit'
  PY
  touch "$out"
''
