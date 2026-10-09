{ pkgs }:

let
  software =
    import ../../lib/software/resolve.nix
      {
        inherit (pkgs) lib;
        platformProviders = (import ../../lib/platforms).packageProviders;
      }
      {
        catalog = import ../../lib/software/catalog.nix { inherit pkgs; };
        requirements = pkgs.lib.genAttrs (builtins.attrNames
          (import ../../lib/software/profiles.nix { inherit pkgs; }).devel
        ) (_: { });
        inherit pkgs;
        packageManager = "nix";
        platform = "nixos";
      };
  profile = pkgs.buildEnv {
    name = "devel-test-profile";
    paths = software.installations.nix.homePackages;
  };
in
pkgs.runCommand "devel-toolchain-check" { nativeBuildInputs = [ profile ]; } ''
  export HOME="$TMPDIR/home"
  mkdir -p "$HOME"

  for tool in git rg fd jq tree curl wget \
    clang clang++ clangd clang-format clang-tidy llvm-ar llvm-config ld.lld lldb \
    cmake ninja meson make autoconf automake libtool m4 pkg-config \
    strings nm readelf objdump objcopy addr2line size strip ar file patch diff python3 \
    gcc g++ gdb git-lfs go node npm java javac protoc rustc cargo tsc telnet; do
    test -x ${profile}/bin/"$tool"
    command -v "$tool"
  done
  test "$(clang -dumpversion)" = "$(llvm-config --version)"
  cc --version | grep -i clang
  c++ --version | grep -i clang
  clang-format --version
  clang-tidy --version
  ld.lld --version
  make --version
  pkg-config --version

  cat > CMakeLists.txt <<'EOF'
  cmake_minimum_required(VERSION 3.20)
  project(devel_check LANGUAGES C CXX)
  set(CMAKE_CXX_STANDARD 20)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  enable_testing()
  add_executable(check_c main.c)
  add_executable(check_cpp main.cpp)
  add_test(NAME c COMMAND check_c)
  add_test(NAME cpp COMMAND check_cpp)
  EOF
  cat > main.c <<'EOF'
  #include <stdio.h>
  int main(void) { return puts("C toolchain OK") < 0; }
  EOF
  cat > main.cpp <<'EOF'
  #include <numeric>
  #include <vector>
  int main() {
    const std::vector<int> values{1, 2, 3};
    return std::accumulate(values.begin(), values.end(), 0) == 6 ? 0 : 1;
  }
  EOF
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
  cmake --build build
  ctest --test-dir build --output-on-failure
  gcc main.c -o check_gcc_c
  g++ -std=c++20 main.cpp -o check_gcc_cpp
  ./check_gcc_c
  ./check_gcc_cpp
  strings build/check_c | grep -F 'C toolchain OK'
  nm build/check_cpp | grep -w main
  file build/check_cpp | grep -F ELF
  ld.lld -r build/CMakeFiles/check_c.dir/main.c.o -o linked.o
  clangd --check="$PWD/main.cpp" --compile-commands-dir="$PWD/build" --log=error
  lldb --batch -o 'target create build/check_cpp' -o 'image lookup -n main'

  python3 -c 'import ssl, sqlite3, sys; print(sys.version)'
  python3 -m venv .venv
  .venv/bin/python -m pip --version
  touch "$out"
''
