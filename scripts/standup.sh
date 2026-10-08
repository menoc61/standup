#!/usr/bin/env bash
# =============================================================================
#  StandUp — project control script (bash / zsh)
# =============================================================================
#
#  One entry point for everything this repository needs: environment setup,
#  dependency resolution, code quality, builds, installs and release packaging
#  for Android, iOS, web, Windows, macOS and Linux.
#
#  Run it with no arguments for an interactive menu, or with a subcommand for
#  scripting and CI. Both paths call the same functions, so the menu can never
#  drift away from what the command line does.
#
#  Quick start
#  -----------
#    ./scripts/standup.sh                 # interactive menu
#    ./scripts/standup.sh init            # first-time project setup
#    ./scripts/standup.sh doctor          # report the state of the toolchain
#    ./scripts/standup.sh build android release
#    ./scripts/standup.sh run windows
#    ./scripts/standup.sh test
#    ./scripts/standup.sh help
#
#  Requirements: bash 4+ (macOS ships bash 3.2; zsh works and is recommended)
# =============================================================================

set -euo pipefail

# ── Locations ────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_ROOT}"

# ── Configuration ────────────────────────────────────────────────────────────

APP_NAME="CSPH StandUp"
ANDROID_PACKAGE="com.healthwellness.standup_app"
IOS_BUNDLE_ID="com.healthwellness.standupApp"
WIDGET_PROVIDER="com.healthwellness.standup_app.widget.StandUpWidgetProvider"
WIDGET_IOS_KIND="CSPHStandUpWidget"

# Platforms the project knows how to build. `all` is expanded by build_all.
PLATFORMS=(android ios web windows macos linux)
# Platforms this host can actually produce. Determined at runtime by `doctor`,
# but a static default keeps `build_all` honest when detection is unavailable.
HOST_UNIX_LIKE=0

# Flutter channel preference. `--flutter-version` and FVM override this.
FLUTTER_VERSION="${STANDUP_FLUTTER_VERSION:-stable}"

# Extra `--dart-define` values, accumulated by `env` and consumed by builders.
SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_KEY="${SUPABASE_PUBLISHABLE_KEY:-}"

# ── Output helpers ───────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ "${NO_COLOR:-}" == "" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_BLUE=$'\033[34m'; C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'
else
  C_RESET=''; C_BOLD=''; C_DIM=''
  C_RED=''; C_GREEN=''; C_YELLOW=''
  C_BLUE=''; C_MAGENTA=''; C_CYAN=''
fi

log()    { printf '%s\n' "$*"; }
info()   { printf '%s▸%s %s\n' "${C_BLUE}" "${C_RESET}" "$*"; }
success(){ printf '%s✓%s %s\n' "${C_GREEN}" "${C_RESET}" "$*"; }
warn()   { printf '%s!%s %s\n' "${C_YELLOW}" "${C_RESET}" "$*" >&2; }
error()  { printf '%s✗%s %s\n' "${C_RED}" "${C_RESET}" "$*" >&2; }
debug()  { [[ "${STANDUP_DEBUG:-0}" == "1" ]] && printf '%s  %s%s\n' "${C_DIM}" "$*" "${C_RESET}" || true; }

section() {
  log ""
  printf '%s%s%s\n' "${C_BOLD}${C_CYAN}" "$*" "${C_RESET}"
  printf '%s%s%s\n' "${C_DIM}" "$(printf '─%.0s' $(seq 1 ${#1}))" "${C_RESET}"
}

die() { error "$*"; exit 1; }

# Confirms a destructive action. Set STANDUP_ASSUME_YES=1 for non-interactive use.
confirm() {
  local prompt="$1"
  if [[ "${STANDUP_ASSUME_YES:-0}" == "1" ]]; then
    return 0
  fi
  local reply
  read -r -p "${C_YELLOW}${prompt}${C_RESET} [y/N] " reply
  [[ "${reply,,}" == "y" || "${reply,,}" == "yes" ]]
}

# ── Toolchain resolution ─────────────────────────────────────────────────────

# Locates flutter, preferring FVM so a project-pinned SDK is used when present.
#
# This matters more than it looks: building against a different Flutter version
# produces different asset bundles and occasionally different behaviour, so
# "works on my machine" is usually a version mismatch rather than a code fault.
resolve_flutter() {
  if [[ -n "${FLUTTER_BIN:-}" ]]; then
    echo "${FLUTTER_BIN}"
    return 0
  fi

  if [[ -f "${PROJECT_ROOT}/.fvmrc" ]] && command -v fvm >/dev/null 2>&1; then
    debug "using fvm"
    echo "fvm"
    return 0
  fi

  if command -v flutter >/dev/null 2>&1; then
    command -v flutter
    return 0
  fi

  # Common install locations that are not on PATH yet.
  local candidates=(
    "${HOME}/development/flutter/bin/flutter"
    "${HOME}/flutter/bin/flutter"
    "/usr/local/flutter/bin/flutter"
    "/opt/flutter/bin/flutter"
    "C:/flutter/bin/flutter"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -x "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done

  return 1
}

FLUTTER=""

require_flutter() {
  if [[ -n "${FLUTTER}" ]]; then
    return 0
  fi
  FLUTTER="$(resolve_flutter)" || die "Flutter not found. Run: ./scripts/standup.sh setup"
  debug "flutter: ${FLUTTER}"
}

# Applies --flutter-version, if it was requested.
#
# Switching SDK versions in place is a machine-level change that FVM exists to
# manage, so this does not try to reinstall anything: it verifies that a
# version-pinning tool is available and tells the user the exact command when it
# is not. Silently building with the wrong version would be worse than refusing.
apply_flutter_version() {
  local requested="${FLUTTER_VERSION}"
  [[ "${requested}" == "stable" || -z "${requested}" ]] && return 0

  require_flutter
  local current
  current="$("${FLUTTER}" --version 2>/dev/null | head -n 1)"

  if [[ "${current}" == *"Flutter ${requested}"* ]]; then
    success "already on Flutter ${requested}"
    return 0
  fi

  if command -v fvm >/dev/null 2>&1; then
    info "switching to Flutter ${requested} via fvm"
    fvm use "${requested}" --force || die "fvm could not activate Flutter ${requested}"
    FLUTTER="fvm"
    return 0
  fi

  die "Flutter ${requested} was requested but the active SDK is different.
  current: ${current}
  Install a version manager, then re-run:
    dart pub global activate fvm
    fvm install ${requested}
    fvm use ${requested} --force
  Or pass a different path: FLUTTER_BIN=/path/to/flutter ./scripts/standup.sh build ..."
}

# Builds a dart-define list from the environment, if credentials are present.
dart_defines() {
  local defines=()
  [[ -n "${SUPABASE_URL}" ]] && defines+=("--dart-define=SUPABASE_URL=${SUPABASE_URL}")
  [[ -n "${SUPABASE_KEY}" ]] && defines+=("--dart-define=SUPABASE_PUBLISHABLE_KEY=${SUPABASE_KEY}")
  printf '%s\n' "${defines[@]:-}"
}

# Runs a flutter subcommand, echoing it first so a CI log is reproducible.
run_flutter() {
  require_flutter
  debug "flutter $*"
  "${FLUTTER}" "$@"
}

# ── Host detection ───────────────────────────────────────────────────────────

host_os() {
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Linux*)  echo "linux" ;;
    Darwin*) echo "macos" ;;
    CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
    *) echo "unknown" ;;
  esac
}

is_windows() { [[ "$(host_os)" == "windows" ]]; }
is_macos()   { [[ "$(host_os)" == "macos" ]]; }
is_linux()   { [[ "$(host_os)" == "linux" ]]; }

# ── doctor ───────────────────────────────────────────────────────────────────

# Reports what is installed and what each platform still needs. Read-only: this
# is the command to run first when something will not build, so it must never
# change the machine.
cmd_doctor() {
  section "Host"
  log "  platform    $(host_os)"
  log "  shell       ${BASH_VERSION:-${ZSH_VERSION:-unknown}}"
  log "  arch        $(uname -m 2>/dev/null || echo unknown)"

  section "Flutter"
  local flutter_path
  if flutter_path="$(resolve_flutter)"; then
    local version
    version="$("${flutter_path}" --version 2>/dev/null | head -n 1)"
    log "  path        ${flutter_path}"
    log "  version     ${version}"
    if [[ -f "${PROJECT_ROOT}/.fvmrc" ]]; then
      log "  fvmrc       $(tr -d '\n' < "${PROJECT_ROOT}/.fvmrc")"
      if command -v fvm >/dev/null 2>&1; then
        success "fvm available, pinned version will be used"
      else
        warn ".fvmrc present but fvm is not installed"
      fi
    fi
  else
    error "Flutter not found — run: ./scripts/standup.sh setup"
  fi

  section "Project files"
  local file
  for file in pubspec.yaml analysis_options.yaml supabase_schema.sql .metadata; do
    if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
      success "${file}"
    else
      warn "${file} missing"
    fi
  done

  section "Dependencies"
  if [[ -f "${PROJECT_ROOT}/pubspec.lock" ]]; then
    if run_flutter pub deps --style=compact >/dev/null 2>&1; then
      success "pubspec.lock resolves"
    else
      warn "pub deps fails — try: ./scripts/standup.sh deps"
    fi
  else
    warn "no pubspec.lock — try: ./scripts/standup.sh deps"
  fi

  section "Generated code"
  if [[ -f "${PROJECT_ROOT}/lib/data/local/app_database.g.dart" ]]; then
    # An older mtime is not proof of staleness: a regeneration that produces
    # identical output does not rewrite the file. So this reports both stamps
    # and points at the command that actually settles the question.
    local generated_at source_at
    generated_at="$(date -r "${PROJECT_ROOT}/lib/data/local/app_database.g.dart" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')"
    source_at="$(date -r "${PROJECT_ROOT}/lib/data/local/app_database.dart" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')"
    log "  generated   ${generated_at}"
    log "  table defs  ${source_at}"
    if [[ "${PROJECT_ROOT}/lib/data/local/app_database.dart" -nt "${PROJECT_ROOT}/lib/data/local/app_database.g.dart" ]]; then
      warn "the table definitions are newer than the generated code"
      log  "    confirm with: ./scripts/standup.sh verify   (it regenerates and diffs)"
    fi
  else
    warn "app_database.g.dart missing — try: ./scripts/standup.sh codegen"
  fi

  section "Android"
  if command -v java >/dev/null 2>&1; then
    local javav
    javav="$(java -version 2>&1 | head -n 1)"
    log  "  java        ${javav}"
  else
    warn "java not on PATH — Android builds need a JDK 17"
  fi
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
  if [[ -n "${sdk}" ]] && [[ -d "${sdk}" ]]; then
    log "  sdk         ${sdk}"
    # Two adb binaries on PATH is the classic cause of
    # "INSTALL_FAILED_USER_RESTRICTED" being misdiagnosed as a device problem.
    local adb_count
    adb_count="$(type -a adb 2>/dev/null | grep -c '^adb is' || echo 0)"
    if [[ "${adb_count}" -gt 1 ]]; then
      warn "multiple adb binaries on PATH (${adb_count}); prefer ${sdk}/platform-tools/adb"
    else
      log "  adb         $(command -v adb 2>/dev/null || echo 'not on PATH')"
    fi
  else
    warn "ANDROID_HOME / ANDROID_SDK_ROOT not set"
  fi
  if [[ -f "${PROJECT_ROOT}/android/key.properties" ]]; then
    success "release signing configured"
  else
    log  "  key.properties absent — release builds fall back to debug signing"
  fi

  section "iOS"
  if is_macos; then
    if command -v xcodebuild >/dev/null 2>&1; then
      success "$(xcodebuild -version 2>/dev/null | head -n 1)"
      if command -v pod >/dev/null 2>&1; then
        success "cocoapods $(pod --version 2>/dev/null)"
      else
        warn "cocoaPods missing — run: sudo gem install cocoapods"
      fi
      if command -v ruby >/dev/null 2>&1; then
        success "ruby available (needed to install the widget target)"
      else
        warn "ruby missing — the widget target cannot be installed automatically"
      fi
    else
      error "xcodebuild not found — install Xcode and run xcode-select --install"
    fi
  else
    warn "iOS builds require macOS with Xcode"
  fi

  section "Desktop toolchains"
  # Flutter builds Windows through CMake + MSVC, and Linux through
  # GTK + a C++ toolchain. Both are checked here because neither failure is
  # obvious from the Flutter side.
  if is_windows; then
    if command -v cmake >/dev/null 2>&1; then
      success "cmake $(cmake --version 2>/dev/null | head -n 1)"
    else
      warn "cmake not on PATH — Visual Studio 2022 with the C++ workload provides it"
    fi
    if command -v cl >/dev/null 2>&1; then
      success "MSVC compiler on PATH"
    else
      warn "MSVC compiler not on PATH — open a Developer Command Prompt or use the VS installer"
    fi
  fi
  if is_linux; then
    local missing=()
    command -v cmake  >/dev/null 2>&1 || missing+=("cmake")
    command -v ninja  >/dev/null 2>&1 || missing+=("ninja-build")
    command -v g++    >/dev/null 2>&1 || missing+=("g++")
    command -v pkg-config >/dev/null 2>&1 || missing+=("pkg-config")
    command -v clang   >/dev/null 2>&1 || missing+=("clang")
    if [[ ${#missing[@]} -eq 0 ]]; then
      success "Linux desktop toolchain present"
    else
      warn "missing: ${missing[*]}"
      log  "  install with: ./scripts/standup.sh setup --linux-deps"
    fi
    if ! pkg-config --exists gtk+-3.0 2>/dev/null; then
      warn "GTK 3 development headers not found (libgtk-3-dev)"
    fi
  fi

  section "Home-screen widgets"
  if [[ -f "${PROJECT_ROOT}/android/app/src/main/kotlin/com/healthwellness/standup_app/widget/StandUpWidgetProvider.kt" ]]; then
    success "Android provider present"
  else
    warn "Android provider missing"
  fi
  if grep -q "StandUpWidgetProvider" "${PROJECT_ROOT}/android/app/src/main/AndroidManifest.xml" 2>/dev/null; then
    success "Android receiver registered"
  else
    warn "Android receiver not registered in the manifest"
  fi
  if [[ -f "${PROJECT_ROOT}/ios/StandUpWidget/CSPHStandUpWidget.swift" ]]; then
    if grep -q "StandUpWidget" "${PROJECT_ROOT}/ios/Runner.xcodeproj/project.pbxproj" 2>/dev/null; then
      success "iOS widget target installed"
    else
      warn "iOS widget sources exist but the Xcode target is missing"
      log  "    install with: ruby scripts/ios/add_widget_target.rb"
    fi
  else
    warn "iOS widget sources missing"
  fi

  log ""
}

# ── setup / init ─────────────────────────────────────────────────────────────

# Installs the project dependencies and, optionally, host packages.
cmd_init() {
  section "Resolving Flutter"
  FLUTTER="$(resolve_flutter)" || die "Flutter not found. Install it from https://docs.flutter.dev/get-started/install"
  success "using ${FLUTTER}"

  section "Project dependencies"
  run_flutter pub get
  success "packages resolved"

  section "Generated code"
  cmd_codegen

  section "Ready"
  success "${APP_NAME} is initialised"
  log "  next: ./scripts/standup.sh doctor"
  log "        ./scripts/standup.sh run windows   # or linux / android / ios"
}

# Installs the host packages each platform needs. Split from `init` because it
# needs elevated rights and should never run silently.
cmd_setup() {
  local want_linux_deps=0
  [[ "${1:-}" == "--linux-deps" ]] && want_linux_deps=1

  section "Project dependencies"
  run_flutter pub get
  success "packages resolved"

  if is_linux && [[ "${want_linux_deps}" == "1" ]]; then
    section "Linux desktop packages"
    # These are the exact packages the Linux build shells out to; installing
    # them by hand is the most common reason `flutter build linux` fails.
    local sudo_cmd=""
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
      if command -v sudo >/dev/null 2>&1; then
        sudo_cmd="sudo"
      else
        die "need root or sudo to install Linux build packages"
      fi
    fi
    info "installing clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev"
    ${sudo_cmd} apt-get update
    ${sudo_cmd} apt-get install -y \
      clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
      libstdc++-12-dev libblkid-dev uuid-dev
    success "Linux desktop packages installed"
  fi

  if is_macos; then
    section "macOS tooling"
    if ! command -v pod >/dev/null 2>&1; then
      warn "cocoaPods missing: sudo gem install cocoapods"
    fi
    if [[ -d "${PROJECT_ROOT}/ios" ]]; then
      (cd ios && pod install) || warn "pod install failed — resolve before building iOS"
    fi
  fi

  section "Done"
  success "environment prepared"
}

# ── Code quality ─────────────────────────────────────────────────────────────

cmd_codegen() {
  section "Drift code generation"
  require_flutter
  if [[ -f "${PROJECT_ROOT}/build.yaml" ]]; then
    run_flutter pub run build_runner build --delete-conflicting-outputs
  else
    run_flutter pub run build_runner build --delete-conflicting-outputs
  fi
  success "generated files refreshed"
}

cmd_analyze() {
  section "Static analysis"
  # --fatal-infos and --fatal-warnings match what CI enforces, so a green local
  # run means a green pipeline.
  run_flutter analyze --fatal-infos --fatal-warnings
  success "no issues"
}

cmd_format() {
  section "Formatting"
  require_flutter
  if [[ "${1:-}" == "--check" ]]; then
    run_flutter format --set-exit-if-changed --output=none lib test
    success "formatting is clean"
  else
    run_flutter format lib test
    success "formatted"
  fi
}

cmd_test() {
  section "Tests"
  local args=()
  [[ -n "${STANDUP_TEST_FILE:-}" ]] && args+=("${STANDUP_TEST_FILE}")
  [[ -n "${STANDUP_TEST_NAME:-}" ]] && args+=("--plain-name" "${STANDUP_TEST_NAME}")
  run_flutter test ${args[@]+"${args[@]}"}
  success "tests passed"
}

# The gate CI runs, in the same order, so local and pipeline agree.
cmd_verify() {
  section "Verify"
  cmd_format --check
  cmd_analyze
  cmd_codegen
  section "Git state"
  if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
    if [[ -n "$(git status --porcelain lib/ 2>/dev/null)" ]]; then
      warn "lib/ changed after code generation — commit the regenerated files"
      git --no-pager diff --stat lib/ || true
    else
      success "generated code is committed"
    fi
  fi
  cmd_test
  log ""
  success "verification passed"
}

# ── Builds ───────────────────────────────────────────────────────────────────

# Reports whether this host can produce [target], with the reason when it cannot.
platform_supported() {
  local target="$1"
  case "${target}" in
    android) command -v java >/dev/null 2>&1 || { warn "android needs a JDK"; return 1; } ;;
    ios)     is_macos || { warn "ios needs macOS + Xcode"; return 1; } ;;
    macos)   is_macos || { warn "macos needs macOS + Xcode"; return 1; } ;;
    windows) is_windows || { warn "windows builds need Windows + Visual Studio C++"; return 1; } ;;
    linux)   is_linux || { warn "linux builds need Linux + GTK dev headers"; return 1; } ;;
    web)     return 0 ;;
    *) die "unknown platform '${target}' (expected one of: ${PLATFORMS[*]} all)" ;;
  esac
  return 0
}

# Copies the Drift web assets into the built web bundle.
#
# `flutter build web` knows nothing about Drift, so sqlite3.wasm and
# drift_worker.js are left out and the deployed app throws on its first query.
# Both live in the resolved drift package, so the version is read from
# pubspec.lock rather than by searching the pub cache: a recursive search takes
# minutes and can pick up a different version's assets.
copy_drift_web_assets() {
  local web_dir="${PROJECT_ROOT}/build/web"
  if [[ ! -d "${web_dir}" ]]; then
    warn "build/web does not exist yet"
    return 0
  fi

  local lock="${PROJECT_ROOT}/pubspec.lock"
  if [[ ! -f "${lock}" ]]; then
    warn "pubspec.lock not found; cannot locate the drift package"
    return 0
  fi

  local version
  version="$(awk '/^  drift:/{found=1; next} found && /version:/{gsub(/"/,"",$2); print $2; exit}' "${lock}")"
  if [[ -z "${version}" ]]; then
    warn "could not determine the drift version from pubspec.lock"
    return 0
  fi

  # The pub cache lives in a different place on each host: PUB_CACHE when set,
  # %LOCALAPPDATA%\Pub\Cache on Windows, ~/.pub-cache elsewhere.
  local cache="${PUB_CACHE:-}"
  if [[ -z "${cache}" ]]; then
    if is_windows; then
      cache="${LOCALAPPDATA}/Pub/Cache"
    else
      cache="${HOME}/.pub-cache"
    fi
  fi

  # Pub normalises the hosted directory separator per platform, but Git Bash on
  # Windows resolves both spellings of the same directory, so try each.
  local drift_dir=""
  local candidate
  for candidate in \
    "${cache}/hosted/pub.dev/drift-${version}" \
    "${cache}/hosted\\pub.dev\\drift-${version}" \
    "${cache}/hosted/pub.dev/drift-${version}" \
    "$(cygpath -u "${cache}" 2>/dev/null)/hosted/pub.dev/drift-${version}"; do
    if [[ -n "${candidate}" ]] && [[ -d "${candidate}" ]]; then
      drift_dir="${candidate}"
      break
    fi
  done

  if [[ -z "${drift_dir}" ]]; then
    error "drift ${version} not found under ${cache}/hosted"
    error "the web build will fail at runtime"
    return 1
  fi
  debug "drift package: ${drift_dir}"

  local missing=0
  if [[ -f "${drift_dir}/drift_worker.js" ]]; then
    cp "${drift_dir}/drift_worker.js" "${web_dir}/drift_worker.js"
    success "build/web/drift_worker.js"
  else
    error "drift_worker.js not found under ${drift_dir}"
    missing=1
  fi

  if [[ -f "${drift_dir}/extension/devtools/build/sqlite3.wasm" ]]; then
    cp "${drift_dir}/extension/devtools/build/sqlite3.wasm" "${web_dir}/sqlite3.wasm"
    success "build/web/sqlite3.wasm"
  else
    error "sqlite3.wasm not found under ${drift_dir}/extension/devtools/build"
    missing=1
  fi

  if [[ "${missing}" -eq 1 ]]; then
    error "the web build will fail at runtime; re-run: ./scripts/standup.sh codegen"
    return 1
  fi
}

cmd_build() {
  local target="${1:-}"
  local mode="${2:-release}"

  if [[ -z "${target}" ]]; then
    die "build requires a platform: ${PLATFORMS[*]} all"
  fi

  if [[ ! "${mode}" =~ ^(debug|profile|release)$ ]]; then
    die "build mode must be debug, profile or release (got '${mode}')"
  fi

  # Requested SDK version is honoured before any work starts, so a version
  # problem fails immediately rather than twenty minutes into a build.
  apply_flutter_version

  if [[ "${target}" == "all" ]]; then
    cmd_build_all "${mode}"
    return
  fi

  section "Building ${target} (${mode})"

  # --skip-build reuses an existing output. CI uses it for the web step: the
  # compile is already done, and only the post-build asset copy is wanted.
  if [[ "${STANDUP_SKIP_BUILD:-0}" != "1" ]]; then
    case "${target}" in
      android)
        run_flutter build apk --${mode} $(dart_defines | tr '\n' ' ')
        success "APK: build/app/outputs/flutter-apk/"
        ;;
      ios)
        # --no-codesign keeps a CI or first-run build from failing on a missing
        # provisioning profile; a real device install goes through `run ios`.
        if [[ "${mode}" == "release" ]]; then
          run_flutter build ios --release --no-codesign $(dart_defines | tr '\n' ' ')
          success "build/ios/iphoneos/ (unsigned — sign in Xcode for a device)"
        else
          run_flutter build ios --${mode} --no-codesign $(dart_defines | tr '\n' ' ')
          success "build/ios/"
        fi
        ;;
      web)
        run_flutter build web --release $(dart_defines | tr '\n' ' ')
        ;;
      windows)
        run_flutter build windows --${mode} $(dart_defines | tr '\n' ' ')
        success "build/windows/x64/runner/"
        ;;
      macos)
        run_flutter build macos --${mode} $(dart_defines | tr '\n' ' ')
        success "build/macos/"
        ;;
      linux)
        run_flutter build linux --${mode} $(dart_defines | tr '\n' ' ')
        success "build/linux/x64/release/bundle/"
        ;;
    esac
  else
    info "--skip-build: reusing the existing output"
  fi

  # The asset copy runs either way: it is cheap, and it is the step most likely
  # to be skipped by accident.
  if [[ "${target}" == "web" ]]; then
    copy_drift_web_assets
    success "build/web/"
  fi
}

# Builds every platform this host can support, skipping the rest with a note.
# Failing one platform should not hide the state of the others, so each is run
# in a subshell and the results are collected.
cmd_build_all() {
  local mode="${1:-release}"
  section "Building every supported platform (${mode})"

  local -a ok=() skipped=() failed=()
  local target
  for target in "${PLATFORMS[@]}"; do
    if ! platform_supported "${target}"; then
      skipped+=("${target}")
      continue
    fi
    if ( cmd_build "${target}" "${mode}" ); then
      ok+=("${target}")
    else
      failed+=("${target}")
    fi
  done

  section "Summary"
  [[ ${#ok[@]}      -gt 0 ]] && success "built:     ${ok[*]}"
  [[ ${#skipped[@]} -gt 0 ]] && warn   "skipped:   ${skipped[*]} (not supported on this host)"
  [[ ${#failed[@]}  -gt 0 ]] && error  "failed:    ${failed[*]}"

  [[ ${#failed[@]} -gt 0 ]] && return 1
  return 0
}

# ── Run and install ──────────────────────────────────────────────────────────

cmd_run() {
  local target="${1:-}"
  [[ -z "${target}" ]] && die "run requires a platform: ${PLATFORMS[*]}"
  platform_supported "${target}" || die "'${target}' is not supported on this host"

  section "Running on ${target}"

  # Mobile targets need a device id. Rather than letting flutter pick one, the
  # available ids are listed and the first is used, so an offline emulator is
  # not silently selected over a connected phone.
  local device_id=""
  case "${target}" in
    android)
      device_id="${ANDROID_DEVICE_ID:-$(first_connected_device android)}"
      if [[ -z "${device_id}" ]]; then
        warn "no android device detected — start an emulator or connect a phone"
        run_flutter devices || true
        return 1
      fi
      info "device ${device_id}"
      run_flutter run -d "${device_id}" $(dart_defines | tr '\n' ' ')
      ;;
    ios)
      device_id="${IOS_DEVICE_ID:-$(first_connected_device ios)}"
      if [[ -z "${device_id}" ]]; then
        warn "no ios device detected — connect a device or start a simulator"
        run_flutter devices || true
        return 1
      fi
      info "device ${device_id}"
      run_flutter run -d "${device_id}" $(dart_defines | tr '\n' ' ')
      ;;
    web)
      # A fixed port keeps the URL stable across restarts.
      info "http://localhost:${STANDUP_WEB_PORT:-8080}"
      run_flutter run -d chrome --web-port "${STANDUP_WEB_PORT:-8080}" $(dart_defines | tr '\n' ' ')
      ;;
    windows|macos|linux)
      run_flutter run -d "${target}" $(dart_defines | tr '\n' ' ')
      ;;
  esac
}

# First device id reported by flutter for [platform], or empty.
first_connected_device() {
  local platform="$1"
  require_flutter
  # `--machine` gives JSON; targetPlatform and id are the two fields needed.
  "${FLUTTER}" devices --machine 2>/dev/null | tr '{' '\n' | while read -r chunk; do
    [[ "${chunk}" == *"\"targetPlatform\":\"${platform}\""* ]] || continue
    if [[ "${chunk}" =~ \"id\":\"([^\"]+)\" ]]; then
      printf '%s' "${BASH_REMATCH[1]}"
      break
    fi
  done
}

cmd_install() {
  local target="${1:-}"
  [[ -z "${target}" ]] && die "install requires a platform: android ios"
  platform_supported "${target}" || die "'${target}' is not supported on this host"

  section "Installing on ${target}"
  if [[ "${target}" == "android" ]]; then
    local apk="build/app/outputs/flutter-apk/app-release.apk"
    [[ -f "${apk}" ]] || die "no APK yet — run: ./scripts/standup.sh build android release"
    # The platform adb is preferred over PATH: a second adb on PATH is the usual
    # cause of INSTALL_FAILED_USER_RESTRICTED being blamed on the device.
    local adb=""
    if [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/platform-tools/adb.exe" ]]; then
      adb="${ANDROID_HOME}/platform-tools/adb.exe"
    elif [[ -n "${ANDROID_HOME:-}" && -x "${ANDROID_HOME}/platform-tools/adb" ]]; then
      adb="${ANDROID_HOME}/platform-tools/adb"
    else
      adb="$(command -v adb || true)"
    fi
    [[ -n "${adb}" ]] || die "adb not found"
    info "devices:"
    "${adb}" devices -l || true
    info "installing ${apk}"
    if "${adb}" install -r "${apk}"; then
      success "installed"
    else
      error "adb install failed"
      log  "On Xiaomi/Redmi, 'Install via USB' is off by default."
      log  "Enable Developer options -> Install via USB, then confirm on the phone."
      return 1
    fi
    "${adb}" shell monkey -p "${ANDROID_PACKAGE}" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 \
      && success "launched" || warn "installed; launch manually if needed"
  elif [[ "${target}" == "ios" ]]; then
    # A signed build is required for a physical device, so this is mostly a
    # reminder rather than an installer.
    warn "iOS installs go through Xcode: open ios/Runner.xcworkspace and run"
    log  "  or use: ./scripts/standup.sh run ios --device-id <udid>"
  fi
}

# ── Widgets ──────────────────────────────────────────────────────────────────

cmd_widget() {
  local action="${1:-info}"
  case "${action}" in
    info)
      section "Home-screen widgets"
      log  "Android provider : ${WIDGET_PROVIDER}"
      log  "Android layout   : android/app/src/main/res/layout/csph_standup_widget.xml"
      log  "iOS kind         : ${WIDGET_IOS_KIND}"
      log  "App Group        : group.${IOS_BUNDLE_ID}"
      log  ""
      log  "Add the widget:"
      log  "  Android: long-press the home screen -> Widgets -> CSPH StandUp"
      log  "  iOS:     long-press the home screen -> + -> search StandUp"
      log  ""
      log  "After a language change or a logged break, run:"
      log  "  ./scripts/standup.sh widget refresh"
      ;;
    refresh)
      # The launcher holds its own copy of the payload, so a rebuild or a fresh
      # install needs an explicit push rather than waiting for a break.
      section "Refreshing widget payload"
      run_flutter test test/widget_snapshot_test.dart
      success "payload contract verified — launch the app once to publish"
      log  "iOS: run scripts/ios/add_widget_target.rb if the widget is not listed."
      ;;
    install-ios)
      is_macos || die "the widget target can only be installed on macOS"
      command -v ruby >/dev/null 2>&1 || die "ruby is required (macOS ships it)"
      section "Installing the iOS widget target"
      ruby scripts/ios/add_widget_target.rb
      success "target installed — now run: (cd ios && pod install)"
      ;;
    *)
      die "widget action must be info, refresh or install-ios"
      ;;
  esac
}

# ── Release ──────────────────────────────────────────────────────────────────

# Packages every distributable artifact and prints where each one landed.
cmd_release() {
  section "Release artifacts"
  local out="${PROJECT_ROOT}/dist"
  mkdir -p "${out}"

  local -a produced=()

  section "Android APK"
  if cmd_build android release; then
    local apk="build/app/outputs/flutter-apk/app-release.apk"
    cp "${apk}" "${out}/standup-android-release.apk"
    produced+=("standup-android-release.apk")
    success "packaged"
  fi

  if is_macos; then
    section "macOS app"
    if cmd_build macos release; then
      local mac_dir="build/macos/Build/Products/Release/${APP_NAME}.app"
      if [[ -d "${mac_dir}" ]]; then
        ditto -c -k --keepParent "${mac_dir}" "${out}/standup-macos.zip" 2>/dev/null \
          && produced+=("standup-macos.zip") && success "packaged"
      fi
    fi
  else
    warn "macOS artifact skipped — requires macOS"
  fi

  if is_windows; then
    section "Windows bundle"
    if cmd_build windows release; then
      local win_dir="build/windows/x64/runner/Release"
      if [[ -d "${win_dir}" ]]; then
        powershell -NoProfile -Command "Compress-Archive -Path '${win_dir}\*' -DestinationPath '${out}\standup-windows.zip' -Force" \
          && produced+=("standup-windows.zip") && success "packaged"
      fi
    fi
  else
    warn "Windows artifact skipped — requires Windows"
  fi

  if is_linux; then
    section "Linux bundle"
    if cmd_build linux release; then
      local lin_dir="build/linux/x64/release/bundle"
      if [[ -d "${lin_dir}" ]]; then
        tar -czf "${out}/standup-linux.tar.gz" -C "$(dirname "${lin_dir}")" bundle \
          && produced+=("standup-linux.tar.gz") && success "packaged"
      fi
    fi
  else
    warn "Linux artifact skipped — requires Linux"
  fi

  if [[ "${STANDUP_BUILD_WEB:-1}" == "1" ]]; then
    section "Web bundle"
    if cmd_build web release; then
      tar -czf "${out}/standup-web.tar.gz" -C build web \
        && produced+=("standup-web.tar.gz") && success "packaged"
    fi
  fi

  section "Artifacts"
  if [[ ${#produced[@]} -eq 0 ]]; then
    warn "nothing was produced"
    return 1
  fi
  for artifact in "${produced[@]}"; do
    local size
    size="$(du -h "${out}/${artifact}" 2>/dev/null | cut -f1 || echo '?')"
    log "  ${artifact}  (${size})"
  done
  log ""
  success "release artifacts in dist/"
}

# ── Maintenance ──────────────────────────────────────────────────────────────

cmd_clean() {
  section "Cleaning"
  confirm "Remove build/, .dart_tool/ and platform build directories?" || { log "cancelled"; return 0; }

  # `flutter clean` plus the two artefact directories that Flutter does not
  # remove on its own: the Linux bundle and the Gradle intermediates that
  # otherwise survive a toolchain upgrade.
  run_flutter clean || warn "flutter clean failed"
  rm -rf "${PROJECT_ROOT}/build"
  rm -rf "${PROJECT_ROOT}/dist"
  for dir in android/.gradle android/app/build ios/Flutter/ephemeral macos/Flutter/ephemeral linux/flutter/ephemeral windows/flutter/ephemeral; do
    [[ -d "${PROJECT_ROOT}/${dir}" ]] && rm -rf "${PROJECT_ROOT}/${dir}" && info "removed ${dir}"
  done
  success "clean"
}

cmd_logs() {
  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    section "Recent Flutter logs"
    run_flutter logs || die "flutter logs needs a device"
  else
    section "Running logs on ${target}"
    run_flutter logs -v
  fi
}

cmd_version() {
  section "Versions"
  run_flutter --version
  log ""
  log "  project      ${APP_NAME}"
  log "  android pkg  ${ANDROID_PACKAGE}"
  log "  ios bundle   ${IOS_BUNDLE_ID}"
  log "  app group    group.${IOS_BUNDLE_ID}"
}

cmd_env() {
  # Credentials are read from the environment or a .env file that is never
  # committed; printing them back would defeat the point, so only their presence
  # is reported.
  section "Supabase environment"
  if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    info "found .env"
    set -a
    # shellcheck disable=SC1091
    source "${PROJECT_ROOT}/.env"
    set +a
  fi

  if [[ -n "${SUPABASE_URL}" ]]; then
    success "SUPABASE_URL set"
  else
    warn "SUPABASE_URL not set — the app runs offline-only"
  fi
  if [[ -n "${SUPABASE_KEY}" ]]; then
    success "SUPABASE_PUBLISHABLE_KEY set"
  else
    warn "SUPABASE_PUBLISHABLE_KEY not set"
  fi
  log ""
  log "Create .env in the project root with:"
  log "  SUPABASE_URL=https://<project-ref>.supabase.co"
  log "  SUPABASE_PUBLISHABLE_KEY=<publishable key>"
  log "The file is gitignored; never commit the service-role key."
}

cmd_deps() {
  section "Dependencies"
  run_flutter pub get
  run_flutter pub outdated || true
}

cmd_help() {
  cat <<EOF
${C_BOLD}${APP_NAME} control script${C_RESET}

${C_BOLD}USAGE${C_RESET}
  ./scripts/standup.sh [command] [args] [options]

${C_BOLD}ENVIRONMENT${C_RESET}
  init                        resolve dependencies and generate code
  setup [--linux-deps]        install project and host packages
  doctor                      report toolchain and platform readiness
  deps                        fetch packages and list outdated ones
  env                         show Supabase configuration status
  version                     tool versions and bundle identifiers

${C_BOLD}CODE${C_RESET}
  analyze                     static analysis (CI parity: fatal infos/warnings)
  format [--check]            format lib/ and test/
  codegen                     regenerate Drift code
  test                        run the test suite
  verify                      format + analyze + codegen drift check + tests

${C_BOLD}BUILD${C_RESET}
  build <platform> [mode]     platforms: ${PLATFORMS[*]} all
                              modes:    debug profile release
  build all [mode]            build every platform this host supports
  run <platform>              launch on a device or emulator
  install android|ios         install a built artifact
  release                     package distributables into dist/
  clean                       remove build output

${C_BOLD}WIDGETS${C_RESET}
  widget info                 where the widget lives and how to add it
  widget refresh              verify the payload contract and re-publish
  widget install-ios          add the WidgetKit target to the Xcode project

${C_BOLD}OTHER${C_RESET}
  logs                        stream device logs
  help                        this text

${C_BOLD}OPTIONS${C_RESET}
  --flutter-version <v>       build with a specific Flutter version (or FVM)
  --assume-yes                skip confirmation prompts
  --debug                     echo every command before running it
  NO_COLOR=1                  disable colour

${C_BOLD}EXAMPLES${C_RESET}
  ./scripts/standup.sh                       interactive menu
  ./scripts/standup.sh init --assume-yes
  ./scripts/standup.sh build android release
  ./scripts/standup.sh build all release
  ./scripts/standup.sh run linux
  ./scripts/standup.sh release --assume-yes
EOF
}

# ── Interactive menu ─────────────────────────────────────────────────────────

# Prompts for one line of input. Reads from stdin so it works when piped, which
# keeps the menu scriptable for demos and screenshots.
prompt() {
  local reply
  printf '%s%s>%s ' "${C_BOLD}${C_CYAN}" "${prompt_count}" "${C_RESET}"
  IFS= read -r reply || reply=""
  prompt_count=$((prompt_count + 1))
  printf '%s' "${reply}"
}

is_blank() { [[ -z "${1// /}" ]]; }

# Menu entry point. Kept separate from `main` so the command line never triggers
# it, which is what lets CI call any subcommand without a tty.
menu() {
  prompt_count=1
  clear 2>/dev/null || true

  printf '%s\n' "${C_BOLD}${C_GREEN}  ${APP_NAME}${C_RESET}  ${C_DIM}— project control${C_RESET}"
  printf '%s\n' "${C_DIM}  interactive menu · 'q' quits · 'h' shows help${C_RESET}"

  while true; do
    section "Menu"
    cat <<EOF
  ${C_BOLD}1${C_RESET}  doctor          check the toolchain
  ${C_BOLD}2${C_RESET}  init            set up the project
  ${C_BOLD}3${C_RESET}  verify          format + analyze + codegen + tests
  ${C_BOLD}4${C_RESET}  run             launch on a platform
  ${C_BOLD}5${C_RESET}  build           build a release artifact
  ${C_BOLD}6${C_RESET}  install         install on a device
  ${C_BOLD}7${C_RESET}  test            run the tests
  ${C_BOLD}8${C_RESET}  widget          home-screen widget tools
  ${C_BOLD}9${C_RESET}  release         package everything distributable
  ${C_BOLD}0${C_RESET}  clean           remove build output
  ${C_BOLD}q${C_RESET}  quit
EOF

    local choice
    choice="$(prompt "select")"

    if is_blank "${choice}"; then continue; fi

    case "${choice}" in
      1) cmd_doctor ;;
      2) cmd_init ;;
      3) cmd_verify ;;
      4)
        local platform
        platform="$(prompt "platform [android|ios|web|windows|macos|linux]")"
        is_blank "${platform}" || cmd_run "${platform}"
        ;;
      5)
        local platform mode
        platform="$(prompt "platform [${PLATFORMS[*]}|all]")"
        if ! is_blank "${platform}"; then
          mode="$(prompt "mode [debug|profile|release] (release)")"
          is_blank "${mode}" && mode="release"
          cmd_build "${platform}" "${mode}" || warn "build failed"
        fi
        ;;
      6)
        local platform
        platform="$(prompt "platform [android|ios]")"
        is_blank "${platform}" || cmd_install "${platform}" || true
        ;;
      7) cmd_test ;;
      8)
        local action
        action="$(prompt "action [info|refresh|install-ios] (info)")"
        is_blank "${action}" && action="info"
        cmd_widget "${action}" || true
        ;;
      9) cmd_release || warn "release incomplete" ;;
      0) cmd_clean || true ;;
      h|H) cmd_help ;;
      q|Q) section "Bye"; return 0 ;;
      *) warn "unknown choice: ${choice}" ;;
    esac

    section ""
    printf '  %senter%s to continue' "${C_DIM}" "${C_RESET}"
    read -r _ || true
  done
}

# ── Entry point ──────────────────────────────────────────────────────────────

main() {
  # Options are collected in a full pass over the arguments rather than only
  # before the command, so `build web release --skip-build` behaves the same as
  # `--skip-build build web release`. Reading them in a leading run only meant a
  # trailing flag silently fell through to the command and was ignored.
  local positionals=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --flutter-version)
        FLUTTER_VERSION="${2:?--flutter-version needs a value}"
        export STANDUP_FLUTTER_VERSION="${FLUTTER_VERSION}"
        shift 2
        ;;
      --skip-build)
        # Reuse an existing build output instead of recompiling. CI uses this for
        # the web step, where only the post-build asset copy is wanted.
        export STANDUP_SKIP_BUILD=1
        shift
        ;;
      --assume-yes|-y)
        export STANDUP_ASSUME_YES=1
        shift
        ;;
      --debug)
        export STANDUP_DEBUG=1
        shift
        ;;
      --no-color)
        export NO_COLOR=1
        shift
        ;;
      --help|-h)
        cmd_help
        return 0
        ;;
      *)
        positionals+=("$1")
        shift
        ;;
    esac
  done

  # Restore the positional arguments so the dispatch below can use "$@".
  set -- "${positionals[@]+"${positionals[@]}"}"

  local command="${1:-menu}"
  shift || true

  case "${command}" in
    menu)    menu ;;
    init)    cmd_init ;;
    setup)   cmd_setup "$@" ;;
    doctor)  cmd_doctor ;;
    deps)    cmd_deps ;;
    env)     cmd_env ;;
    version) cmd_version ;;
    analyze) cmd_analyze ;;
    format)  cmd_format "$@" ;;
    codegen) cmd_codegen ;;
    test)    cmd_test ;;
    verify)  cmd_verify ;;
    build)   cmd_build "$@" ;;
    run)     cmd_run "$@" ;;
    install) cmd_install "$@" ;;
    widget)  cmd_widget "$@" ;;
    release) cmd_release ;;
    clean)   cmd_clean ;;
    logs)    cmd_logs "$@" ;;
    help)    cmd_help ;;
    *)
      error "unknown command '${command}'"
      log ""
      cmd_help
      return 1
      ;;
  esac
}

main "$@"
