/* eslint-disable no-console */
import { execaSync } from "execa";
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const PROJECT_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const REPO_DIR = join(PROJECT_ROOT, "tmp/discourse-repo");
const OUTPUT_PATH = join(PROJECT_ROOT, "data/commits.json");
const ORIGIN = "https://github.com/discourse/discourse";
const BASE_TAG = "v3.4.0";

const git = (args) => execaSync("git", args, { cwd: REPO_DIR }).stdout;
const lines = (str) => str.trim().split("\n").filter(Boolean);

function fetchCommits(baseTag, branch) {
  const format = "%H%x1f%P%x1f%an%x1f%cI%x1f%s%x1f%b%x00";
  const stdout = git(["log", `--format=${format}`, `${baseTag}..${branch}`]);

  return stdout
    .split("\x00")
    .filter((r) => r.trim())
    .map((record) => {
      const [hash, parents, author, date, subject, body] = record.split("\x1f");
      return {
        hash: hash.trim(),
        parents: parents.trim().split(" ").filter(Boolean),
        author: author.trim(),
        date: date.trim(),
        subject: subject.trim(),
        body: body.trim(),
        version: "",
      };
    });
}

function computeVersions(commits, commitToTag) {
  const cache = {};

  function compute(hash) {
    if (cache[hash]) {
      return cache[hash];
    }
    if (commitToTag[hash]) {
      return (cache[hash] = { tag: commitToTag[hash], distance: 0 });
    }

    // BFS to count all commits between this commit and nearest tag
    const visited = new Set();
    const queue = [hash];
    let tag = null;

    while (queue.length) {
      const current = queue.shift();
      if (visited.has(current)) {
        continue;
      }
      if (commitToTag[current]) {
        tag ??= commitToTag[current];
        continue;
      }
      visited.add(current);
      commits[current]?.parents.forEach((p) => queue.push(p));
    }

    return (cache[hash] = tag ? { tag, distance: visited.size } : null);
  }

  for (const hash of Object.keys(commits)) {
    const v = compute(hash);
    if (v) {
      const version = v.tag.replace(/^v/, "");
      commits[hash].version = v.distance
        ? `${version} +${v.distance}`
        : version;
    }
  }
}

function main() {
  mkdirSync(REPO_DIR, { recursive: true });
  git(["init", "--bare", "."]);
  git([
    "fetch",
    ORIGIN,
    "--prune",
    "--refmap=''",
    "+refs/heads/main:refs/heads/main",
    "+refs/heads/stable:refs/heads/stable",
    "+refs/heads/latest:refs/heads/latest",
    "+refs/heads/release/*:refs/heads/release/*",
    "+refs/tags/*:refs/tags/*",
  ]);

  const branches = [
    "main",
    "stable",
    "latest",
    ...lines(
      git(["for-each-ref", "--format=%(refname:short)", "refs/heads/release/"])
    ),
  ];

  // Collect commits from all branches
  const commits = {};
  console.log(`Collecting commits from: ${branches.join(", ")}`);
  for (const branch of branches) {
    let count = 0;
    for (const commit of fetchCommits(BASE_TAG, branch)) {
      if (commit.hash && !commits[commit.hash]) {
        commits[commit.hash] = commit;
        count++;
      }
    }
    console.log(`  ${branch}: ${count} new`);
  }
  console.log(`Total: ${Object.keys(commits).length} commits\n`);

  // Build tag mappings (single git call for all tags)
  const tags = {};
  const tagFormat =
    "%(refname:short) %(if)%(*objectname)%(then)%(*objectname)%(else)%(objectname)%(end)";
  for (const line of lines(
    git(["for-each-ref", `--format=${tagFormat}`, "refs/tags/v*"])
  )) {
    const [tag, hash] = line.split(" ");
    if (commits[hash]) {
      tags[tag] = hash;
    }
  }
  tags[BASE_TAG] ??= git(["rev-parse", `${BASE_TAG}^{}`]).trim();

  // Reverse mapping: commit -> tag (prefer clean versions like v1.2.3)
  const commitToTag = {};
  for (const [tag, hash] of Object.entries(tags)) {
    if (!commitToTag[hash] || /^v\d+\.\d+\.\d+$/.test(tag)) {
      commitToTag[hash] = tag;
    }
  }

  // Compute versions
  console.log("Computing versions...");
  computeVersions(commits, commitToTag);

  // Resolve branch refs
  const branchRefs = {};
  for (const branch of branches) {
    branchRefs[branch] = git(["rev-parse", `${branch}^{}`]).trim();
  }

  // Write output
  mkdirSync(dirname(OUTPUT_PATH), { recursive: true });
  writeFileSync(
    OUTPUT_PATH,
    JSON.stringify(
      {
        commits,
        refs: { tags, branches: branchRefs },
        baseTag: BASE_TAG,
      },
      null,
      2
    )
  );

  console.log(
    `Written ${Object.keys(commits).length} commits to ${OUTPUT_PATH}`
  );
}

try {
  main();
} catch (e) {
  console.error(e);
  process.exit(1);
}
