{ pkgs }:
pkgs.runCommand "greeter-session-check" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  export PYTHONDONTWRITEBYTECODE=1
  python3 - ${../../../assets/helpers}/common/greeter-session.py <<'PY'
  import importlib.util, json, pathlib, sys, tempfile
  sys.path.insert(0, str(pathlib.Path(sys.argv[1]).parent))
  spec = importlib.util.spec_from_file_location('greeter', sys.argv[1])
  helper = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(helper)
  with tempfile.TemporaryDirectory() as root:
      helper.seed(root, 'niri')
      memory = pathlib.Path(root) / '.local/state/memory.json'
      assert json.loads(memory.read_text())['lastSessionDesktopId'] == 'niri.desktop'
      data = {'lastSessionDesktopId': 'gnome.desktop', 'lastSessionId': '/usr/share/wayland-sessions/gnome.desktop', 'lastSuccessfulUser': 'test'}
      memory.write_text(json.dumps(data))
      helper.seed(root, 'niri')
      assert json.loads(memory.read_text()) == data
      helper.seed(root, 'gnome')
      state = json.loads(memory.read_text())
      assert state['lastSessionDesktopId'] == 'gnome.desktop'
      assert state['lastSuccessfulUser'] == 'test'
      assert 'lastSessionId' not in state
  PY
  touch "$out"
''
