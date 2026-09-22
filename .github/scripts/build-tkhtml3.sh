#!/bin/sh
# Build and install Tkhtml 3 from github.com/hkoba/tkhtml3 at a given
# commit, for the Tcl/Tk found on this machine (Debian/Ubuntu layout by
# default). Used by the CI workflow; usable locally as well.
#
#   build-tkhtml3.sh [COMMIT] [PREFIX]
#
# Requires: gcc, make, curl, tar, tcl-dev, tk-dev (tclConfig.sh/tkConfig.sh).
set -eu

COMMIT=${1:-bf51fe3e4467a121afaeb3f26be0090d071b6188}
PREFIX=${2:-/usr/local}
# Tcl's default auto_path on Debian includes /usr/local/lib/tcltk.
LIBDIR=${TKHTML_LIBDIR:-$PREFIX/lib/tcltk}

TCL_CONFIG=${TCL_CONFIG:-$(find /usr/lib /usr/lib64 -name tclConfig.sh 2>/dev/null | head -1)}
TK_CONFIG=${TK_CONFIG:-$(find /usr/lib /usr/lib64 -name tkConfig.sh 2>/dev/null | head -1)}
if [ -z "$TCL_CONFIG" ] || [ -z "$TK_CONFIG" ]; then
    echo "tclConfig.sh / tkConfig.sh not found (install tcl-dev and tk-dev)" >&2
    exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
curl -sSL "https://github.com/hkoba/tkhtml3/archive/$COMMIT/tkhtml3.tar.gz" | tar xz
cd "tkhtml3-$COMMIT"

./configure --with-tcl="$(dirname "$TCL_CONFIG")" --with-tk="$(dirname "$TK_CONFIG")" \
    --prefix="$PREFIX" --libdir="$LIBDIR" --enable-shared
make CFLAGS="-fPIC -O2"
${SUDO:-} make install

echo "Tkhtml installed under $LIBDIR:"
ls "$LIBDIR"/Tkhtml*
