#!/usr/bin/env bash
# Read-only resolution of external values the file-only implementer needs:
# exact compatible npm versions for T001 and image digests for T015/T016.
# Validates the npm set by resolving a lockfile in a temporary directory
# (--package-lock-only --ignore-scripts: nothing is installed or executed).
# Prints JSON on stdout and saves it to .agent-out/implementation-inputs.json.
source "$(dirname "$0")/lib.sh"
out=".agent-out/implementation-inputs.json"
mkdir -p .agent-out

SEMVER="$(dirname "$(readlink -f "$(command -v npm)")")/../node_modules/semver"
[ -d "$SEMVER" ] || fail "semver module not found next to npm"

npm_json="$(SEMVER="$SEMVER" node <<'EOF'
const { execFileSync } = require("child_process");
const semver = require(process.env.SEMVER);
const view = (spec, field) => {
  const raw = execFileSync("npm", ["view", spec, field, "--json"], { encoding: "utf8" }).trim();
  return raw ? JSON.parse(raw) : null;
};
const stable = (name) => [].concat(view(name, "versions")).filter((v) => !semver.prerelease(v));
const maxSat = (name, ranges) => {
  const ok = stable(name).filter((v) => ranges.every((r) => semver.satisfies(v, r)));
  if (!ok.length) throw new Error(`no stable ${name} satisfies ${ranges.join(" AND ")}`);
  return semver.rsort(ok)[0];
};

const next = view("next", "dist-tags").latest;
const nextPeers = view(`next@${next}`, "peerDependencies") || {};
const react = maxSat("react", [nextPeers.react]);
const reactDom = maxSat("react-dom", [nextPeers["react-dom"], react]);
const eslintConfigNext = maxSat("eslint-config-next", [next]);
const ecnPeers = view(`eslint-config-next@${eslintConfigNext}`, "peerDependencies") || {};
const ecnDeps = view(`eslint-config-next@${eslintConfigNext}`, "dependencies") || {};

const eslintRanges = [ecnPeers.eslint].filter(Boolean);
const tsRanges = [ecnPeers.typescript].filter(Boolean);
for (const [dep, range] of Object.entries(ecnDeps)) {
  const v = maxSat(dep, [range]);
  const peers = view(`${dep}@${v}`, "peerDependencies") || {};
  if (peers.eslint) eslintRanges.push(peers.eslint);
  if (peers.typescript) tsRanges.push(peers.typescript);
}
const pg = view("pg", "dist-tags").latest;
const versions = {
  dependencies: {
    next,
    react,
    "react-dom": reactDom,
    pg,
  },
  devDependencies: {
    typescript: maxSat("typescript", tsRanges),
    "@types/node": maxSat("@types/node", ["^24"]),
    "@types/react": maxSat("@types/react", [`^${semver.major(react)}`]),
    "@types/react-dom": maxSat("@types/react-dom", [`^${semver.major(reactDom)}`]),
    "@types/pg": view("@types/pg", "dist-tags").latest,
    eslint: maxSat("eslint", eslintRanges),
    "eslint-config-next": eslintConfigNext,
  },
};
process.stdout.write(JSON.stringify({ versions, constraints: { eslint: eslintRanges, typescript: tsRanges, next_peers: nextPeers } }));
EOF
)" || fail "npm version resolution failed"

# Prove the exact set resolves (no ERESOLVE) without installing or running scripts.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
jq '{name: "pin-check", version: "0.0.0", private: true} + .versions' <<<"$npm_json" > "$tmp/package.json"
(cd "$tmp" && npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null 2>"$tmp/err.log") \
  || { tail -20 "$tmp/err.log" >&2; fail "pinned npm set does not resolve"; }

digest() {  # digest <image:tag> → image:tag@sha256:...
  local d
  d="$(docker buildx imagetools inspect "$1" | awk '/^Digest:/ {print $2; exit}')"
  [[ "$d" == sha256:* ]] || fail "could not resolve digest for $1"
  echo "$1@$d"
}
node_image="$(digest node:24-bookworm-slim)"
postgres_image="$(digest postgres:17-bookworm)"

jq -n --argjson npm "$npm_json" --arg node "$node_image" --arg pg "$postgres_image" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '{
    resolved_at: $at,
    npm_exact_versions: $npm.versions,
    npm_peer_constraints_used: $npm.constraints,
    npm_validation: "exact set resolved with npm install --package-lock-only --ignore-scripts in a temporary directory",
    images: { node_24: $node, postgres_17: $pg }
  }' | tee "$out"
