#!/usr/bin/env bash
# Checks releases.json against the format in releases.schema.json (plus unique versions and the 256 KiB limit).
#
#   ./check-releases.sh [file]      default: releases.json
set -euo pipefail

file="${1:-releases.json}"
[ -f "$file" ] || { echo "no such file: $file" >&2; exit 1; }
size="$(wc -c < "$file")"
[ "$size" -le 262144 ] || { echo "$file is $size bytes, the limit is 262144" >&2; exit 1; }

jq empty "$file" 2>/dev/null || { echo "$file is not valid JSON" >&2; exit 1; }
problems="$(jq -r '
  def semver: type == "string" and test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$");
  def ghurl: type == "string" and test("^https://github\\.com/[^/ ]+/[^/ ]+/[^ ]+$");
  def stamp: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
  def fields: ["version", "released_at", "severity", "rbac_changed", "summary", "notes_url", "compare_url"];
  def release_problems:
    . as $r
    | if type != "object" then ["a release is not an object"] else
        ($r.version // "?") as $v
        | [ (keys[] | select(IN(fields[]) | not) | "\($v): unknown field \(.)"),
            (fields[] | . as $f | select($f != "compare_url" and ($r | has($f) | not)) | "\($v): missing \($f)"),
            (select(has("version") and (.version | semver | not)) | "\($v): version is not plain semver"),
            (select(has("released_at") and (.released_at | stamp | not)) | "\($v): released_at is not YYYY-MM-DDTHH:MM:SSZ"),
            (select(has("severity") and (.severity | IN("normal", "security") | not)) | "\($v): severity is normal or security"),
            (select(has("rbac_changed") and (.rbac_changed | type != "boolean")) | "\($v): rbac_changed is not a boolean"),
            (select(has("summary") and ((.summary | type != "string") or (.summary | length) < 1 or (.summary | length) > 200)) | "\($v): summary is 1 to 200 characters"),
            (select(has("notes_url") and (.notes_url | ghurl | not)) | "\($v): notes_url is not an https github.com URL"),
            (select(has("compare_url") and (.compare_url | ghurl | not)) | "\($v): compare_url is not an https github.com URL")
          ]
      end;
  if type != "object" then ["the file is not an object"]
  elif (keys | sort) != ["releases", "schema_version"] then ["the top level has exactly schema_version and releases"]
  elif .schema_version != 1 then ["schema_version is not 1"]
  elif (.releases | type) != "array" then ["releases is not an array"]
  elif (.releases | length) > 200 then ["more than 200 releases"]
  else
    [.releases[] | release_problems[]]
    + ([.releases[].version?] | group_by(.) | map(select(length > 1) | "duplicate version \(.[0])"))
  end
  | .[]' "$file")"

if [ -n "$problems" ]; then
  echo "$file is not valid:" >&2
  echo "$problems" | sed 's/^/  /' >&2
  exit 1
fi
echo "$file ok: $(jq '.releases | length' "$file") releases"
