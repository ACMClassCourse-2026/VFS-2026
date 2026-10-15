#!/usr/bin/env bash
# =============================================================================
#  test_bonus.sh - VFS-2026 Bonus public test runner
#
#  Source: vfs_bonus.cpp (use --src to test another implementation/submission)
#  Tests: data_bonus_public/*.in, with matching *.out files
#  Method: compile the source, run each .in, and compare output byte for byte
#
#  Bonus includes all core commands plus redo / rm -r / tree.
#  The largest Bonus public test is public10_random_extra_large_mix (n = 100000).
#
#  Examples:
#    ./test_bonus.sh                      Run all public tests (10 by default)
#    ./test_bonus.sh 02                   Run tests containing "02" (tree workflow)
#    ./test_bonus.sh public07 public09    Run specific tests
#    ./test_bonus.sh --src my_impl.cpp    Test another implementation
#    ./test_bonus.sh --bin ./a.exe        Test an existing executable
#    ./test_bonus.sh --hidden             Include data_bonus_hidden tests
#    ./test_bonus.sh -t 30 -v             Use a 30s timeout and show full diffs
#    ./test_bonus.sh --list               List tests without running them
#    ./test_bonus.sh -h                   Show all options
#
#  Exit codes: 0 = all pass, 1 = test failure, 2 = environment/argument error
# =============================================================================
set -uo pipefail

# --- Default settings ---------------------------------------------------------
SRC_DEFAULT="vfs_bonus.cpp"          # Source under test (reference implementation)
DATA_DEFAULT="data_bonus_public"     # Public test directory
BUILD_DEFAULT=".cache/test_bonus"    # Build/output directory (.cache is ignored)
HIDDEN_CORNER="data_bonus_hidden/hidden_corner_cases"
HIDDEN_PRESSURE="data_bonus_hidden/hidden_pressure_test"

SRC=""                               # Source file (empty uses SRC_DEFAULT)
DATA_DIRS=()                         # Test directories
BUILD_DIR=""                         # Build/output directory
USE_BIN=""                           # Existing executable (skips compilation)
TIMEOUT=1                            # Timeout per test: 1 second (1000ms); 0 = unlimited
MAX_DIFF=40                          # Maximum diff lines shown on failure
SHOW_DIFF=0                          # -n: show a truncated diff on failure
EXPEXT="out"                         # Expected output extension (ans in packages)
VERBOSE=0                            # -v: show full diff/stderr on failure
QUIET=0                              # -q: show only failures and the summary
LIST_ONLY=0                          # --list: list tests only
WANT_HIDDEN=0                        # --hidden: include hidden tests
FILTERS=()                           # Positional arguments: test name substrings
CXX="${CXX:-}"                       # Compiler (auto-detected by default)
CXXFLAGS=(-std=c++17 -O2)            # Compiler flags

# --- Locate the repository root -----------------------------------------------
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd) || exit 2
# Use relative paths: MinGW may corrupt non-ASCII absolute paths via ANSI encoding.
cd "$SCRIPT_DIR" || exit 2

SRC="${SRC:-$SRC_DEFAULT}"
BUILD_DIR="${BUILD_DIR:-$BUILD_DEFAULT}"

usage() {
    cat <<EOF
Usage: $0 [options] [test-name filters...]

Source: ${SRC_DEFAULT} (required commands plus redo / rm -r / tree)
Tests:  ${DATA_DEFAULT}/publicNN_*.in with matching .out files

Options:
  -s, --src FILE     Source file to test (default: ${SRC_DEFAULT})
  -b, --bin FILE     Use an existing executable; skip compilation
  -d, --data DIR     Test directory (repeatable; default: ${DATA_DEFAULT})
      --hidden       Include hidden tests (${HIDDEN_CORNER} and ${HIDDEN_PRESSURE})
  -e, --ext EXT      Expected output extension (default: out; ans in 3207/)
  -t, --timeout SEC  Timeout per test in seconds (default: 1s = 1000ms; 0 = unlimited)
  -n, --max-diff N   Enable failure details with at most N diff lines
  -v, --verbose      Show full diff and stderr on failure
  -q, --quiet        Show only failed tests and the summary
      --list         List tests without running them
  -h, --help         Show this help

Positional arguments filter test names by substring (excluding the extension).
For example, "$0 02" runs only public02_tree_workflow.

Exit codes: 0 = all pass, 1 = test failure, 2 = environment/argument error
EOF
}

die() {
    printf '%s: %s\n' "$0" "$*" >&2
    exit 2
}

# --- Millisecond timing: prefer EPOCHREALTIME to avoid extra date processes -----
now_ms() {
    local s us t
    if [ -n "${EPOCHREALTIME:-}" ]; then
        case "$EPOCHREALTIME" in
            *.*)
                s="${EPOCHREALTIME%%.*}"
                us="${EPOCHREALTIME#*.}"
                printf '%s' $((s * 1000 + 10#$us / 1000))
                ;;
            *) printf '%s' $((EPOCHREALTIME * 1000)) ;;
        esac
        return 0
    fi
    t=$(date +%s%N 2>/dev/null || true)
    case "$t" in
        '' | *[!0-9]*) printf '%s' $(($(date +%s) * 1000)) ;;
        *) printf '%s' $((t / 1000000)) ;;
    esac
}

# --- Compiler detection -------------------------------------------------------
pick_compiler() {
    local c
    if [ -n "$CXX" ]; then
        printf '%s' "$CXX"
        return 0
    fi
    for c in g++ clang++; do
        if command -v "$c" >/dev/null 2>&1; then
            printf '%s' "$c"
            return 0
        fi
    done
    for c in /c/msys64/mingw64/bin/g++.exe /c/msys64/ucrt64/bin/g++.exe \
        /c/Program\ Files/LLVM/bin/clang++.exe; do
        if [ -x "$c" ]; then
            printf '%s' "$c"
            return 0
        fi
    done
    return 1
}

# --- Argument parsing ---------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        -s | --src)
            [ $# -ge 2 ] || die "$1 requires an argument"
            SRC="$2"
            shift 2
            ;;
        --src=*)
            SRC="${1#*=}"
            shift
            ;;
        -b | --bin)
            [ $# -ge 2 ] || die "$1 requires an argument"
            USE_BIN="$2"
            shift 2
            ;;
        --bin=*)
            USE_BIN="${1#*=}"
            shift
            ;;
        -d | --data)
            [ $# -ge 2 ] || die "$1 requires an argument"
            DATA_DIRS+=("$2")
            shift 2
            ;;
        --data=*)
            DATA_DIRS+=("${1#*=}")
            shift
            ;;
        --hidden)
            WANT_HIDDEN=1
            shift
            ;;
        -e | --ext)
            [ $# -ge 2 ] || die "$1 requires an argument"
            EXPEXT="$2"
            shift 2
            ;;
        -t | --timeout)
            [ $# -ge 2 ] || die "$1 requires an argument"
            TIMEOUT="$2"
            shift 2
            ;;
        -n | --max-diff)
            [ $# -ge 2 ] || die "$1 requires an argument"
            MAX_DIFF="$2"
            SHOW_DIFF=1
            shift 2
            ;;
        -v | --verbose)
            VERBOSE=1
            shift
            ;;
        -q | --quiet)
            QUIET=1
            shift
            ;;
        --list)
            LIST_ONLY=1
            shift
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        --)
            shift
            while [ $# -gt 0 ]; do
                FILTERS+=("$1")
                shift
            done
            ;;
        -*)
            die "Unknown option: $1 (use -h for help)"
            ;;
        *)
            FILTERS+=("$1")
            shift
            ;;
    esac
done

# --- Assemble test directories ------------------------------------------------
if [ "${#DATA_DIRS[@]}" -eq 0 ]; then
    DATA_DIRS=("$DATA_DEFAULT")
fi
if [ "$WANT_HIDDEN" -eq 1 ]; then
    DATA_DIRS+=("$HIDDEN_CORNER" "$HIDDEN_PRESSURE")
fi

# --- Collect tests ------------------------------------------------------------
inputs=()
for d in "${DATA_DIRS[@]}"; do
    [ -d "$d" ] || die "Test directory not found: $d"
    while IFS= read -r f; do
        [ -n "$f" ] && inputs+=("$f")
    done < <(find "$d" -maxdepth 1 -name '*.in' -type f | sort)
done
[ "${#inputs[@]}" -gt 0 ] || die "No .in test files found"

# An empty filter list selects all tests.
filter_match() {
    local base="$1" f
    [ "${#FILTERS[@]}" -eq 0 ] && return 0
    for f in "${FILTERS[@]}"; do
        case "$base" in
            *"$f"*) return 0 ;;
        esac
    done
    return 1
}

# --- List tests only ----------------------------------------------------------
if [ "$LIST_ONLY" -eq 1 ]; then
    printf 'Source     : %s\n' "$SRC"
    printf 'Test dirs  : %s\n' "${DATA_DIRS[*]}"
    printf 'Total tests: %d\n' "${#inputs[@]}"
    for in in "${inputs[@]}"; do
        printf '  %s\n' "$(basename "$in" .in)"
    done
    exit 0
fi

# --- Print run settings -------------------------------------------------------
printf 'Source     : %s\n' "$SRC"
printf 'Test dirs  : %s\n' "${DATA_DIRS[*]}"

# --- Prepare the executable ---------------------------------------------------
mkdir -p "$BUILD_DIR" || die "Cannot create build directory: $BUILD_DIR"

if [ -n "$USE_BIN" ]; then
    exe="$USE_BIN"
    [ -f "$exe" ] || die "Executable not found: $exe"
else
    [ -f "$SRC" ] || die "Source file not found: $SRC"
    CXX=$(pick_compiler) || die "No C++ compiler found (set CXX=... or install g++)"
    base_exe=$(basename "${SRC%.*}")
    exe="$BUILD_DIR/$base_exe.exe"
    build_stamp="$exe.build-info"
    # Timestamps alone cannot distinguish a Windows build from a Linux build.
    build_signature=$(
        printf 'Platform: %s\n' "$(uname -s)"
        printf 'Compiler: %s\n' "$(command -v "$CXX")"
        printf 'Target: %s\n' "$("$CXX" -dumpmachine)"
        printf 'Version: %s\n' "$("$CXX" --version)"
        printf 'Source: %s\n' "$SRC"
        printf 'Flags:'
        printf ' %q' "${CXXFLAGS[@]}"
        printf '\n'
    )
    cached_signature=""
    [ ! -f "$build_stamp" ] || cached_signature=$(<"$build_stamp")
    if [ ! -f "$exe" ] || [ "$SRC" -nt "$exe" ] || [ "$build_signature" != "$cached_signature" ]; then
        rm -f "$exe" "$build_stamp" # Never reuse a stale or incompatible build.
        if ! "$CXX" "${CXXFLAGS[@]}" -o "$exe" "$SRC"; then
            printf 'Compilation failed: %s\n' "$SRC" >&2
            exit 2
        fi
        printf '%s\n' "$build_signature" >"$build_stamp" || die "Cannot save build information: $build_stamp"
    fi
fi
CR=$(printf '\r') # Normalize Windows CRLF output only when needed.
if [ "$TIMEOUT" -gt 0 ]; then
    command -v timeout >/dev/null 2>&1 || die "The timeout command is required (install coreutils or use -t 0)"
fi

# Measure process startup overhead with an empty n=0 run.
printf '0\n' >"$BUILD_DIR/_baseline.in"
baseline_ms=0
b0=$(now_ms)
if "$exe" <"$BUILD_DIR/_baseline.in" >/dev/null 2>&1; then
    baseline_ms=$(($(now_ms) - b0))
fi
printf -- '-------------------------------------------------------\n'

# --- Run each test ------------------------------------------------------------
pass=0
fail=0
failed_names=()
t_start=$(now_ms)

for in in "${inputs[@]}"; do
    base=$(basename "$in" .in)
    exp="${in%.in}.$EXPEXT"

    filter_match "$base" || continue

    if [ ! -f "$exp" ]; then
        printf '[FAIL] %-32s Missing expected output: %s\n' "$base" "$exp"
        fail=$((fail + 1))
        failed_names+=("$base")
        continue
    fi

    raw="$BUILD_DIR/$base.raw"
    norm="$raw"
    errf="$BUILD_DIR/$base.stderr"

    t0=$(now_ms)
    if [ "$TIMEOUT" -gt 0 ]; then
        timeout "$TIMEOUT" "$exe" <"$in" >"$raw" 2>"$errf"
        rc=$?
    else
        "$exe" <"$in" >"$raw" 2>"$errf"
        rc=$?
    fi
    t1=$(now_ms)
    elapsed=$((t1 - t0))
    if [ "$elapsed" -ge "$baseline_ms" ]; then
        net=$((elapsed - baseline_ms))
    else
        net=0
    fi

    if [ "$rc" -ne 0 ]; then
        if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then
            reason="Timeout (>$((TIMEOUT * 1000))ms)"
        else
            reason="Exit code $rc"
        fi
        printf '[FAIL] %-32s %6dms  %s\n' "$base" "$elapsed" "$reason"
        if [ -s "$errf" ] && { [ "$VERBOSE" -eq 1 ] || [ "$SHOW_DIFF" -eq 1 ]; }; then
            if [ "$VERBOSE" -eq 1 ]; then
                sed 's/^/         stderr| /' "$errf"
            else
                sed 's/^/         stderr| /' "$errf" | head -n 10
            fi
        fi
        fail=$((fail + 1))
        failed_names+=("$base")
        continue
    fi

    # Compare raw output first; Linux/WSL output already uses LF.
    if ! cmp -s "$exp" "$raw"; then
        # On a mismatch, check for Windows CRLF and normalize before retrying.
        need_norm=0
        if IFS= read -r firstline <"$raw"; then
            case "$firstline" in *"$CR") need_norm=1 ;; esac
        fi
        if [ "$need_norm" -eq 1 ]; then
            sed -e "s/${CR}\$//" "$raw" >"$BUILD_DIR/$base.norm"
            norm="$BUILD_DIR/$base.norm"
        fi
    fi

    if cmp -s "$exp" "$norm"; then
        if [ "$QUIET" -eq 0 ]; then
            printf '[PASS] %-32s %6dms (net %dms)\n' "$base" "$elapsed" "$net"
        fi
        pass=$((pass + 1))
        continue
    fi

    printf '[FAIL] %-32s %6dms  Output mismatch\n' "$base" "$elapsed"
    if [ "$VERBOSE" -eq 1 ] || [ "$SHOW_DIFF" -eq 1 ]; then
        first=$(cmp "$exp" "$norm" 2>&1 | head -n 1)
        printf '         %s\n' "$first"
        printf '         Expected: %s\n' "$exp"
        printf '         Actual  : %s%s\n' "$norm" \
            "$(if [ "$norm" != "$raw" ]; then printf ' (CRLF normalized)'; fi)"
        if [ "$VERBOSE" -eq 1 ]; then
            diff -u "$exp" "$norm" || true
        else
            diff -u "$exp" "$norm" | head -n "$MAX_DIFF" || true
        fi
    fi
    fail=$((fail + 1))
    failed_names+=("$base")
done

t_end=$(now_ms)
total_ms=$((t_end - t_start))

# --- Summary ------------------------------------------------------------------
printf -- '-------------------------------------------------------\n'
if [ "${#failed_names[@]}" -gt 0 ]; then
    printf 'Failed tests: %s\n' "${failed_names[*]}"
fi
printf 'Tests run: %d; passed: %d; failed: %d; total time: %d.%03ds\n' \
    $((pass + fail)) "$pass" "$fail" $((total_ms / 1000)) $((total_ms % 1000))
if [ "$fail" -eq 0 ] && [ "$pass" -gt 0 ]; then
    exit 0
fi
exit 1
