{
  lib,
  runCommand,
}:
pkg:
let
  # Variants of qemu with and without graphical support
  pkgsWithOverrides = {
    "default" = pkg;
    "guiSupport" = pkg.override {
      sdlSupport = true;
      gtkSupport = true;
    };
  };

  # Each variant has one or two relevant executables
  executableNamesPerVariant = {
    "qemu-espressif" = [
      "qemu-system-xtensa"
      "qemu-system-riscv32"
    ];
    "qemu-esp32" = [ "qemu-system-xtensa" ];
    "qemu-esp32c3" = [ "qemu-system-riscv32" ];
  };

  # And each of these possible executables supports one or two architectures
  archPerExecutableName = {
    "qemu-system-xtensa" = [
      "esp32"
      "esp32s3"
    ];
    "qemu-system-riscv32" = [ "esp32c3" ];
  };

  # Check that the version is correct (also checked in versionCheckHook, but a bit more cleanly
  mkCheckVersion =
    override: exeName:
    let
      exe = lib.getExe' pkgsWithOverrides.${override} exeName;
    in
    "echo Checking version\necho ${exe}\n${exe} --version | grep '${
      pkgsWithOverrides.${override}.version
    }' || (echo ERROR: Did not find expected version; exit 1)\n";

  # Check that the version without graphical support indeed doesn't report graphical support
  # and check that the version with graphical support indeed reports graphical support
  mkCheckGraphics =
    override: exeName:
    let
      exe = lib.getExe' pkgsWithOverrides.${override} exeName;
    in
    "echo Checking graphics options\n${
      if (override == "guiSupport") then
        "${exe} --display help | grep -e 'gtk'\n${exe} --display help | grep -e 'sdl' || (echo ERROR: Did not find expected graphics options; exit 1)\n"
      else
        "! ${exe} --display help | grep -e '^[a-z]\\+$' | grep -v -e 'none\\|dbus' || (echo ERROR: Found unexpected graphics options; exit 1)\n"
    }";

  # Check if all expected architectures are supported
  mkCheckArch =
    override: exeName:
    let
      exe = lib.getExe' pkgsWithOverrides.${override} exeName;
    in
    lib.concatMapStrings (
      arch:
      "echo Checking machine options\n${exe} --machine help | grep '^${arch} ' || (echo ERROR: Did not find expected architecture; exit 1)\n"
    ) archPerExecutableName.${exeName};

  # Concatenate all these commands
  concatChecks = lib.concatMapStrings (
    override:
    lib.concatMapStrings (
      exeName:
      mkCheckVersion override exeName + mkCheckGraphics override exeName + mkCheckArch override exeName
    ) executableNamesPerVariant.${pkgsWithOverrides.${override}.pname}
  ) (lib.attrNames pkgsWithOverrides);
in
runCommand "check-${pkg.name}" { } ''
  echo Checking variant ${pkg.pname}
  ${concatChecks}
  mkdir "$out"
''
