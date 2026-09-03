#!/bin/bash

set -euo pipefail

test_root="$(mktemp -d)"
trap 'rm -rf -- "$test_root"' EXIT
fake_bin="$test_root/bin"
data_home="$test_root/data"
mkdir -p "$fake_bin"

cat > "$fake_bin/xdg-mime" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "$1" == "default" ]]; then
  printf '%s\n' "$2" > "$TEST_HANDLER_STATE"
elif [[ "$1" == "query" && "$2" == "default" ]]; then
  cat "$TEST_HANDLER_STATE"
else
  exit 2
fi
EOF

cat > "$fake_bin/update-desktop-database" <<'EOF'
#!/bin/bash
exit 0
EOF

cat > "$fake_bin/noop" <<'EOF'
#!/bin/bash
exit 0
EOF

chmod +x "$fake_bin/xdg-mime" "$fake_bin/update-desktop-database" "$fake_bin/noop"
for command_name in curl jq secret-tool xdg-open python; do
  ln -s "$fake_bin/noop" "$fake_bin/$command_name"
done

export TEST_HANDLER_STATE="$test_root/handler"
export XDG_DATA_HOME="$data_home"
export PATH="$fake_bin:$PATH"

"$(dirname "$0")/../setup" --register-only

desktop_file="$data_home/applications/io.github.timsweetman1.whoop.desktop"
test -f "$desktop_file"
grep -Fq 'MimeType=x-scheme-handler/omarchy-whoop;' "$desktop_file"
grep -Fq "Exec=$(cd "$(dirname "$0")/.." && pwd)/bin/whoop-bridge callback %u" "$desktop_file"
test "$(stat -c '%a' "$desktop_file")" = "644"
