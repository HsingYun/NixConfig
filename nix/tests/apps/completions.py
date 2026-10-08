"""Exercise installed completion scripts in real Bash, Zsh and Fish shells."""
import os
from pathlib import Path
import subprocess
import sys

package = Path(sys.argv[1])
env = dict(os.environ, NIXMAN_PACKAGE=str(package), PATH=f"{package}/bin:{os.environ['PATH']}")
scripts = {
    "bash": ("share/bash-completion/completions/nixman.bash", '''
        source "$NIXMAN_PACKAGE/share/bash-completion/completions/nixman.bash"
        COMP_WORDS=(nixman generation gc --o)
        COMP_CWORD=3
        _nixman_complete
        printf '%s\\n' "${COMPREPLY[@]}"
    '''),
    "zsh": ("share/zsh/site-functions/_nixman", '''
        fpath=("$NIXMAN_PACKAGE/share/zsh/site-functions" $fpath)
        autoload -Uz _nixman
        words=(nixman generation gc --o)
        CURRENT=4
        compadd() { print -rl -- "${@:2}"; }
        _files() { return 1; }
        _nixman
    '''),
    "fish": ("share/fish/vendor_completions.d/nixman.fish", '''
        source "$NIXMAN_PACKAGE/share/fish/vendor_completions.d/nixman.fish"
        complete -C 'nixman generation gc --o'
    '''),
}
for shell, (relative, source) in scripts.items():
    assert (package / relative).is_file()
    exported = subprocess.check_output([str(package / "bin/nixman"), "completion", shell], text=True, env=env)
    assert exported == (package / relative).read_text()
    arguments = {"bash": ["--noprofile", "--norc"], "zsh": ["-f"], "fish": ["--no-config"]}[shell]
    result = subprocess.check_output([shell, *arguments, "-c", source], text=True, env=env)
    candidates = {line.split("\t")[0] for line in result.splitlines()}
    assert {"--oldest", "--older-than"} <= candidates, (shell, result)
print("Packaged Bash/Zsh/Fish completions passed")
