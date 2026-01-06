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
  const FIELD_SEP = "%x1f";
  const RECORD_SEP = "%x00";
  const format =
    [
      "%H", // commit hash
      "%P", // parent hashes
      "%an", // author name
      "%cI", // commit date (ISO 8601)
      "%s", // subject
      "%b", // body
    ].join(FIELD_SEP) + RECORD_SEP;
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

    if (!tag) {
      throw new Error(`No tag found for commit ${hash}`);
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
  console.log(`Fetching from ${ORIGIN}...`);
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
  console.log("Fetch complete.\n");

  const branches = [
    "main",
    "stable",
    "latest",
    ...lines(
      git(["for-each-ref", "--format=%(refname:short)", "refs/heads/release/"])
    ),
  ];

  // Collect commits from all branches (BASE_TAG^ includes the base commit itself)
  const commits = {};
  console.log(`Collecting commits from: ${branches.join(", ")}`);
  for (const branch of branches) {
    let count = 0;
    for (const commit of fetchCommits(`${BASE_TAG}^`, branch)) {
      if (commit.hash && !commits[commit.hash]) {
        commits[commit.hash] = commit;
        count++;
      }
    }
    console.log(`  ${branch}: ${count} new`);
  }
  console.log(`Total: ${Object.keys(commits).length} commits\n`);

  // Build tag mappings (single git call for all tags)
  const allTags = {}; // All tags for BFS traversal
  const tags = {}; // Only tags pointing to commits in our set (for output)
  const tagFormat =
    "%(refname:short) %(if)%(*objectname)%(then)%(*objectname)%(else)%(objectname)%(end)";
  for (const line of lines(
    git(["for-each-ref", `--format=${tagFormat}`, "refs/tags/v*"])
  )) {
    const [tag, hash] = line.split(" ");
    allTags[tag] = hash;
    if (commits[hash]) {
      tags[tag] = hash;
    }
  }

  // Reverse mapping: commit -> tag (prefer clean versions like v1.2.3)
  // Uses allTags so BFS can find older tags via merge commits
  const commitToTag = {};
  for (const [tag, hash] of Object.entries(allTags)) {
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
