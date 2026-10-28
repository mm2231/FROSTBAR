#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 mm2231 and FrostBar contributors
"""Generate FrostBar.xcodeproj from the checked-in source tree.

The project is generated rather than committed by hand because it is almost
entirely mechanical: two targets, one local Swift package, one remote package,
two copy phases. Keeping it generated means `git diff` on the project file is
never the source of truth -- `Package.swift`, the xcconfigs and this script are.

Object identifiers are derived from stable path keys, so regenerating an
unchanged tree produces a byte-identical project file.

Usage:
    python3 scripts/gen_xcodeproj.py [--check]

`--check` writes nothing and exits non-zero if the project on disk differs.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "FrostBar.xcodeproj"
PBXPROJ = PROJECT / "project.pbxproj"

APP_PRODUCT = "FrostBar"
HELPER_PRODUCT = "FrostBarHelper"
SPARKLE_MINIMUM = "2.6.0"
SPARKLE_URL = "https://github.com/sparkle-project/Sparkle"

LAUNCH_DAEMON_GLOB = "Helper/LaunchDaemon"


# ---------------------------------------------------------------------------
# Identifiers


def oid(key: str) -> str:
    """24 uppercase hex characters, stable for a given semantic key."""
    return hashlib.md5(key.encode("utf-8")).hexdigest().upper()[:24]


# ---------------------------------------------------------------------------
# pbxproj serialisation


SAFE = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./$")


def quote(value: str) -> str:
    if value and all(character in SAFE for character in value):
        return value
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )
    return f'"{escaped}"'


def serialise(value, indent: int = 0) -> str:
    pad = "\t" * indent
    inner = "\t" * (indent + 1)

    if isinstance(value, str):
        return quote(value)

    if isinstance(value, list):
        if not value:
            return "(\n" + pad + ")"
        lines = ["("]
        for item in value:
            lines.append(inner + serialise(item, indent + 1) + ",")
        lines.append(pad + ")")
        return "\n".join(lines)

    if isinstance(value, dict):
        if not value:
            return "{\n" + pad + "}"
        lines = ["{"]
        for key in sorted(value, key=lambda item: (item != "isa", item)):
            lines.append(inner + quote(key) + " = " + serialise(value[key], indent + 1) + ";")
        lines.append(pad + "}")
        return "\n".join(lines)

    raise TypeError(f"cannot serialise {type(value)!r}")


class Project:
    def __init__(self) -> None:
        self.objects: dict[str, dict] = {}

    def add(self, key: str, isa: str, **fields) -> str:
        identifier = oid(key)
        if identifier in self.objects:
            raise SystemExit(f"duplicate object id for key: {key}")
        self.objects[identifier] = {"isa": isa, **fields}
        return identifier

    def render(self, root_object: str) -> str:
        body = []
        for identifier in sorted(self.objects):
            body.append(f"\t\t{identifier} = {serialise(self.objects[identifier], 2)};")
        objects = "\n".join(body)
        return (
            "// !$*UTF8*$!\n"
            "{\n"
            "\tarchiveVersion = 1;\n"
            "\tclasses = {\n"
            "\t};\n"
            "\tobjectVersion = 56;\n"
            "\tobjects = {\n"
            f"{objects}\n"
            "\t};\n"
            f"\trootObject = {root_object};\n"
            "}\n"
        )


# ---------------------------------------------------------------------------
# File tree


FILE_TYPES = {
    ".swift": "sourcecode.swift",
    ".plist": "text.plist.xml",
    ".entitlements": "text.plist.entitlements",
    ".xcconfig": "text.xcconfig",
    ".md": "net.daringfireball.markdown",
    ".sh": "text.script.sh",
    ".py": "text.script.python",
    ".yml": "text.yaml",
    ".yaml": "text.yaml",
    ".json": "text.json",
}


def file_type(path: Path) -> str:
    if path.name in {"LICENSE", "NOTICE", "README", "CHANGELOG"}:
        return "text"
    return FILE_TYPES.get(path.suffix.lower(), "text")


class Tree:
    """Nested representation of the navigator groups."""

    def __init__(self) -> None:
        self.files: dict[str, Path] = {}
        self.groups: dict[str, "Tree"] = {}

    def insert(self, relative: Path, full: Path | None = None) -> None:
        full = full or relative
        if len(relative.parts) == 1:
            self.files[relative.name] = ROOT / full
            return
        head, tail = relative.parts[0], Path(*relative.parts[1:])
        self.groups.setdefault(head, Tree()).insert(tail, full)


def swift_sources(*directories: str) -> list[str]:
    paths: list[str] = []
    for directory in directories:
        base = ROOT / directory
        for path in sorted(base.rglob("*.swift")):
            paths.append(str(path.relative_to(ROOT)))
    return paths


# ---------------------------------------------------------------------------
# Project construction


def build() -> str:
    project = Project()

    app_sources = swift_sources("App") + swift_sources("Shared/HelperProtocol")
    helper_sources = swift_sources("Helper") + swift_sources("Shared/HelperProtocol")

    # --- file references ---------------------------------------------------
    file_refs: dict[str, str] = {}

    def ref(relative: str) -> str:
        if relative in file_refs:
            return file_refs[relative]
        path = ROOT / relative
        identifier = project.add(
            f"file:{relative}",
            "PBXFileReference",
            lastKnownFileType=file_type(path),
            path=relative,
            sourceTree="<group>",
        )
        file_refs[relative] = identifier
        return identifier

    app_product = project.add(
        "product:app",
        "PBXFileReference",
        explicitFileType="wrapper.application",
        includeInIndex="0",
        path=f"{APP_PRODUCT}.app",
        sourceTree="BUILT_PRODUCTS_DIR",
    )
    helper_product = project.add(
        "product:helper",
        "PBXFileReference",
        explicitFileType="compiled.mach-o.executable",
        includeInIndex="0",
        path=HELPER_PRODUCT,
        sourceTree="BUILT_PRODUCTS_DIR",
    )

    # --- groups ------------------------------------------------------------
    tree = Tree()
    for relative in app_sources + helper_sources:
        tree.insert(Path(relative))
    for relative in [
        "Package.swift",
        "Team.xcconfig",
        "README.md",
        "CHANGELOG.md",
        "SECURITY.md",
        "LICENSE",
        "NOTICE",
        "Config/App.xcconfig",
        "Config/Helper.xcconfig",
        "Config/Shared.xcconfig",
        "Config/AppInfo.plist",
        "Config/HelperInfo.plist",
        "Config/FrostBar.entitlements",
        "Config/FrostBarHelper.entitlements",
    ]:
        tree.insert(Path(relative))

    # Whole directories are added by listing what is on disk, so new scripts
    # and ADRs appear without editing this file.
    for directory, suffix in [("scripts", None), ("docs/adr", ".md"), (".github/workflows", ".yml")]:
        base = ROOT / directory
        if not base.is_dir():
            continue
        for path in sorted(base.iterdir()):
            if path.is_dir() or (suffix and path.suffix != suffix):
                continue
            tree.insert(path.relative_to(ROOT))

    for path in sorted((ROOT / LAUNCH_DAEMON_GLOB).glob("*.plist")):
        tree.insert(path.relative_to(ROOT))

    products_group = project.add(
        "group:Products",
        "PBXGroup",
        children=[app_product, helper_product],
        name="Products",
        sourceTree="<group>",
    )

    def emit_group(node: Tree, key: str, name: str) -> str:
        children: list[str] = []
        for file_name in sorted(node.files):
            children.append(ref(str(node.files[file_name].relative_to(ROOT))))
        for group_name in sorted(node.groups):
            children.append(
                emit_group(node.groups[group_name], f"{key}/{group_name}", group_name)
            )
        return project.add(
            f"group:{key}",
            "PBXGroup",
            children=children,
            name=name,
            sourceTree="<group>",
        )

    main_children = [emit_group(tree, "root", "FrostBar"), products_group]
    main_group = project.add(
        "group:main",
        "PBXGroup",
        children=main_children,
        sourceTree="<group>",
    )

    # --- packages ----------------------------------------------------------
    sparkle_package = project.add(
        "package:sparkle",
        "XCRemoteSwiftPackageReference",
        repositoryURL=SPARKLE_URL,
        requirement={"kind": "upToNextMajorVersion", "minimumVersion": SPARKLE_MINIMUM},
    )
    local_package = project.add(
        "package:local",
        "XCLocalSwiftPackageReference",
        relativePath=".",
    )

    def package_product(key: str, name: str, package: str) -> str:
        return project.add(
            f"product-dep:{key}",
            "XCSwiftPackageProductDependency",
            package=package,
            productName=name,
        )

    sparkle_dependency = package_product("app-sparkle", "Sparkle", sparkle_package)
    app_core = package_product("app-core", "FrostBarCore", local_package)
    app_modes = package_product("app-modes", "FrostBarModes", local_package)
    app_profiles = package_product("app-profiles", "FrostBarProfiles", local_package)
    app_smc = package_product("app-smc", "FrostBarSMC", local_package)
    helper_core = package_product("helper-core", "FrostBarCore", local_package)
    helper_modes = package_product("helper-modes", "FrostBarModes", local_package)
    helper_smc = package_product("helper-smc", "FrostBarSMC", local_package)

    # --- build files -------------------------------------------------------
    def build_file(relative: str, target: str) -> str:
        return project.add(
            f"build:{target}:{relative}",
            "PBXBuildFile",
            fileRef=ref(relative),
        )

    def product_build_file(key: str, reference: str) -> str:
        return project.add(f"build:{key}", "PBXBuildFile", productRef=reference)

    helper_copy = project.add(
        "build:copy:helper",
        "PBXBuildFile",
        fileRef=helper_product,
        settings={"ATTRIBUTES": ["CodeSignOnCopy"]},
    )

    app_source_phase = project.add(
        "phase:app:sources",
        "PBXSourcesBuildPhase",
        buildActionMask="2147483647",
        files=[build_file(path, "app") for path in app_sources],
        runOnlyForDeploymentPostprocessing="0",
    )
    helper_source_phase = project.add(
        "phase:helper:sources",
        "PBXSourcesBuildPhase",
        buildActionMask="2147483647",
        files=[build_file(path, "helper") for path in helper_sources],
        runOnlyForDeploymentPostprocessing="0",
    )

    app_frameworks_phase = project.add(
        "phase:app:frameworks",
        "PBXFrameworksBuildPhase",
        buildActionMask="2147483647",
        files=[
            product_build_file("app-framework:core", app_core),
            product_build_file("app-framework:modes", app_modes),
            product_build_file("app-framework:profiles", app_profiles),
            product_build_file("app-framework:smc", app_smc),
            product_build_file("app-framework:sparkle", sparkle_dependency),
        ],
        runOnlyForDeploymentPostprocessing="0",
    )
    helper_frameworks_phase = project.add(
        "phase:helper:frameworks",
        "PBXFrameworksBuildPhase",
        buildActionMask="2147483647",
        files=[
            product_build_file("helper-framework:core", helper_core),
            product_build_file("helper-framework:modes", helper_modes),
            product_build_file("helper-framework:smc", helper_smc),
        ],
        runOnlyForDeploymentPostprocessing="0",
    )

    app_resources_phase = project.add(
        "phase:app:resources",
        "PBXResourcesBuildPhase",
        buildActionMask="2147483647",
        files=[],
        runOnlyForDeploymentPostprocessing="0",
    )

    embed_helper_phase = project.add(
        "phase:app:embed-helper",
        "PBXCopyFilesBuildPhase",
        buildActionMask="2147483647",
        dstPath="",
        dstSubfolderSpec="6",
        files=[helper_copy],
        name="Embed Helper",
        runOnlyForDeploymentPostprocessing="0",
    )

    daemon_script = (
        'set -euo pipefail\n'
        'PLIST="$(/bin/ls "$SRCROOT/Helper/LaunchDaemon/"*.plist | /usr/bin/head -n 1)"\n'
        'DEST="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Library/LaunchDaemons"\n'
        '/bin/mkdir -p "$DEST"\n'
        '/bin/cp "$PLIST" "$DEST/"\n'
    )
    daemon_phase = project.add(
        "phase:app:daemon-plist",
        "PBXShellScriptBuildPhase",
        alwaysOutOfDate="1",
        buildActionMask="2147483647",
        files=[],
        inputFileListPaths=[],
        inputPaths=[],
        name="Copy LaunchDaemon plist",
        outputFileListPaths=[],
        outputPaths=[],
        runOnlyForDeploymentPostprocessing="0",
        shellPath="/bin/sh",
        shellScript=daemon_script,
    )

    release_guard = (
        'set -euo pipefail\n'
        'if [ "$CONFIGURATION" = "Release" ]; then\n'
        '  if [ "$TEAM_ID" = "YOURTEAMID" ] || [ -z "$TEAM_ID" ]; then\n'
        '    echo "error: set TEAM_ID in Team.xcconfig before a release build." >&2\n'
        '    exit 1\n'
        '  fi\n'
        '  case "$SPARKLE_PUBLIC_ED_KEY" in\n'
        '    "" | REPLACE_WITH*)\n'
        '      echo "error: set SPARKLE_PUBLIC_ED_KEY in Team.xcconfig before a release build." >&2\n'
        '      exit 1\n'
        '      ;;\n'
        '  esac\n'
        'fi\n'
    )
    guard_phase = project.add(
        "phase:app:release-guard",
        "PBXShellScriptBuildPhase",
        alwaysOutOfDate="1",
        buildActionMask="2147483647",
        files=[],
        inputFileListPaths=[],
        inputPaths=[],
        name="Validate release configuration",
        outputFileListPaths=[],
        outputPaths=[],
        runOnlyForDeploymentPostprocessing="0",
        shellPath="/bin/sh",
        shellScript=release_guard,
    )

    # --- target dependencies ----------------------------------------------
    proxy = project.add(
        "proxy:helper",
        "PBXContainerItemProxy",
        containerPortal=oid("project"),
        proxyType="1",
        remoteGlobalIDString=oid("target:helper"),
        remoteInfo=HELPER_PRODUCT,
    )
    app_dependency = project.add(
        "dependency:app-helper",
        "PBXTargetDependency",
        target=oid("target:helper"),
        targetProxy=proxy,
    )

    # --- build configurations ---------------------------------------------
    def configurations(owner: str, base: str | None, debug: dict, release: dict) -> str:
        identifiers = []
        for name, settings in (("Debug", debug), ("Release", release)):
            fields = dict(settings)
            if base:
                fields["baseConfigurationReference"] = ref(base)
            identifiers.append(
                project.add(
                    f"config:{owner}:{name}",
                    "XCBuildConfiguration",
                    buildSettings=fields,
                    name=name,
                )
            )
        return project.add(
            f"config-list:{owner}",
            "XCConfigurationList",
            buildConfigurations=identifiers,
            defaultConfigurationIsVisible="0",
            defaultConfigurationName="Release",
        )

    project_config_list = configurations(
        "project",
        "Config/Shared.xcconfig",
        debug={
            "DEBUG_INFORMATION_FORMAT": "dwarf",
            "ENABLE_TESTABILITY": "YES",
            "GCC_OPTIMIZATION_LEVEL": "0",
            "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
            "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
            "ONLY_ACTIVE_ARCH": "YES",
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
            "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
        },
        release={
            "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
            "ENABLE_NS_ASSERTIONS": "NO",
            "MTL_ENABLE_DEBUG_INFO": "NO",
            "ONLY_ACTIVE_ARCH": "NO",
            "SWIFT_COMPILATION_MODE": "wholemodule",
            "SWIFT_OPTIMIZATION_LEVEL": "-O",
        },
    )

    app_config_list = configurations("app", "Config/App.xcconfig", {}, {})
    helper_config_list = configurations("helper", "Config/Helper.xcconfig", {}, {})

    # --- targets -----------------------------------------------------------
    app_target = project.add(
        "target:app",
        "PBXNativeTarget",
        buildConfigurationList=app_config_list,
        buildPhases=[
            app_source_phase,
            app_frameworks_phase,
            app_resources_phase,
            guard_phase,
            embed_helper_phase,
            daemon_phase,
        ],
        buildRules=[],
        dependencies=[app_dependency],
        name=APP_PRODUCT,
        packageProductDependencies=[
            app_core,
            app_modes,
            app_profiles,
            app_smc,
            sparkle_dependency,
        ],
        productName=APP_PRODUCT,
        productReference=app_product,
        productType="com.apple.product-type.application",
    )

    helper_target = project.add(
        "target:helper",
        "PBXNativeTarget",
        buildConfigurationList=helper_config_list,
        buildPhases=[helper_source_phase, helper_frameworks_phase],
        buildRules=[],
        dependencies=[],
        name=HELPER_PRODUCT,
        packageProductDependencies=[helper_core, helper_modes, helper_smc],
        productName=HELPER_PRODUCT,
        productReference=helper_product,
        productType="com.apple.product-type.tool",
    )

    project.add(
        "project",
        "PBXProject",
        attributes={
            "BuildIndependentTargetsInParallel": "1",
            "LastSwiftUpdateCheck": "1500",
            "LastUpgradeCheck": "1500",
            "TargetAttributes": {
                app_target: {"CreatedOnToolsVersion": "15.0"},
                helper_target: {"CreatedOnToolsVersion": "15.0"},
            },
        },
        buildConfigurationList=project_config_list,
        compatibilityVersion="Xcode 14.0",
        developmentRegion="en",
        hasScannedForEncodings="0",
        knownRegions=["en", "Base"],
        mainGroup=main_group,
        packageReferences=[local_package, sparkle_package],
        productRefGroup=products_group,
        projectDirPath="",
        projectRoot="",
        targets=[app_target, helper_target],
    )

    return project.render(oid("project"))


# ---------------------------------------------------------------------------
# Scheme


SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion = "1500" version = "1.7">
   <BuildAction parallelizeBuildables = "YES" buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "YES" buildForProfiling = "YES" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{target}"
               BuildableName = "{product}.app"
               BlueprintName = "{product}"
               ReferencedContainer = "container:FrostBar.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
         <BuildActionEntry buildForTesting = "YES" buildForRunning = "NO" buildForProfiling = "NO" buildForArchiving = "YES" buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{helper}"
               BuildableName = "{helper_product}"
               BlueprintName = "{helper_product}"
               ReferencedContainer = "container:FrostBar.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction buildConfiguration = "Debug" selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB" launchStyle = "0" useCustomWorkingDirectory = "NO" ignoresPersistentStateOnLaunch = "NO" debugDocumentVersioning = "YES" debugServiceExtension = "internal" allowLocationSimulation = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "{product}.app"
            BlueprintName = "{product}"
            ReferencedContainer = "container:FrostBar.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction buildConfiguration = "Release" shouldUseLaunchSchemeArgsEnv = "YES" savedToolIdentifier = "" useCustomWorkingDirectory = "NO" debugDocumentVersioning = "YES">
      <BuildableProductRunnable runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{target}"
            BuildableName = "{product}.app"
            BlueprintName = "{product}"
            ReferencedContainer = "container:FrostBar.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction buildConfiguration = "Release" revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the project on disk is current instead of writing it",
    )
    arguments = parser.parse_args()

    contents = build()
    scheme = SCHEME.format(
        target=oid("target:app"),
        product=APP_PRODUCT,
        helper=oid("target:helper"),
        helper_product=HELPER_PRODUCT,
    )
    scheme_path = PROJECT / "xcshareddata" / "xcschemes" / f"{APP_PRODUCT}.xcscheme"

    if arguments.check:
        if not PBXPROJ.exists() or PBXPROJ.read_text() != contents:
            print("FrostBar.xcodeproj is out of date; run scripts/gen_xcodeproj.py", file=sys.stderr)
            return 1
        if not scheme_path.exists() or scheme_path.read_text() != scheme:
            print("FrostBar.xcscheme is out of date; run scripts/gen_xcodeproj.py", file=sys.stderr)
            return 1
        print("FrostBar.xcodeproj is up to date.")
        return 0

    PBXPROJ.parent.mkdir(parents=True, exist_ok=True)
    PBXPROJ.write_text(contents)
    scheme_path.parent.mkdir(parents=True, exist_ok=True)
    scheme_path.write_text(scheme)

    workspace = PROJECT / "project.xcworkspace"
    workspace.mkdir(exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<Workspace version = "1.0">\n'
        '   <FileRef location = "self:">\n'
        "   </FileRef>\n"
        "</Workspace>\n"
    )

    for directory in ("xcshareddata", "xcuserdata"):
        (PROJECT / directory).mkdir(exist_ok=True)

    print(f"wrote {PBXPROJ.relative_to(ROOT)} ({len(contents.splitlines())} lines)")
    print(f"wrote {scheme_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
