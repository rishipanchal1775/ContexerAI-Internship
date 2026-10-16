#!/usr/bin/env bash
fail=0
for tool in git python3 docker; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "OK   $tool: $($tool --version 2>&1 | head -n1)"
  else
    echo "FAIL $tool is not installed"
    fail=1
  fi
done
exit $fail
