/* eslint-disable no-console */
import { execa, execaSync } from "execa";
import { mkdirSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

// Get project root directory
const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, "..");
const REPO_DIR = join(PROJECT_ROOT, "tmp/discourse-repo");
const BASE_TAG = "v3.4.0";
const BATCH_SIZE = 100; // Process this many commits in parallel

function runOrFail(command, args, options = {}) {
  return execaSync(command, args, {
    cwd: REPO_DIR,
    ...options,
  });
}

async function runAsync(command, args, options = {}) {
  const result = await execa(command, args, {
    cwd: REPO_DIR,
    ...options,
  });
  return result.stdout;
}

const ORIGIN = "https://github.com/discourse/discourse";
const FETCH_REFSPECS = [
  "+refs/heads/main:refs/heads/main",
  "+refs/heads/latest:refs/heads/latest",
  "+refs/heads/stable:refs/heads/stable",
  "+refs/heads/release/*:refs/heads/release/*",
  "+refs/tags/*:refs/tags/*",
];

async function main() {
  mkdirSync(REPO_DIR, { recursive: true });

  runOrFail("git", ["init", "--bare", "."]);
  runOrFail("git", [
    "fetch",
    ORIGIN,
    "--prune",
    "--refmap=''",
    ...FETCH_REFSPECS,
  ]);

  // 1. Collect all unique commits from all branches since BASE_TAG
  let branches = ["main", "stable", "latest"];

  // Expand release/* branches
  const releaseBranchesResult = runOrFail("git", [
    "for-each-ref",
    "--format=%(refname:short)",
    "refs/heads/release/",
  ]);
  const releaseBranches = releaseBranchesResult.stdout
    .trim()
    .split("\n")
    .filter((b) => b);
  branches = branches.concat(releaseBranches);

  // 2. Collect commits with full info using git log
  const commits = {};
  const FIELD_SEP_GIT = "%x1f"; // For git format string
  const RECORD_SEP_GIT = "%x00";
  const FIELD_SEP = "\x1f"; // For parsing output
  const RECORD_SEP = "\x00";

  console.log(`Collecting commits from branches: ${branches.join(", ")}`);

  for (const branch of branches) {
      const format = `%H${FIELD_SEP_GIT}%P${FIELD_SEP_GIT}%an${FIELD_SEP_GIT}%cI${FIELD_SEP_GIT}%s${FIELD_SEP_GIT}%b${RECORD_SEP_GIT}`;
      const result = await runAsync("git", [
        "log",
        `--format=${format}`,
        `${BASE_TAG}..${branch}`,
      ]);

      let branchCommitCount = 0;
      const records = result.split(RECORD_SEP).filter((r) => r.trim());

      for (const record of records) {
        const fields = record.split(FIELD_SEP);
        const commitHash = fields[0]?.trim() || "";

        if (!commitHash || commits[commitHash]) {
          continue; // Skip empty or duplicates
        }

        branchCommitCount++;
        commits[commitHash] = {
          hash: commitHash,
          parents: (fields[1]?.trim() || "").split(" ").filter((p) => p),
          author: fields[2]?.trim() || "",
          date: fields[3]?.trim() || "",
          subject: fields[4]?.trim() || "",
          body: fields[5]?.trim() || "",
          version: "", // Will be filled by git describe
        };
      }
      console.log(`  ${branch}: ${branchCommitCount} new commits`);
    
  }

  const allCommitHashes = Object.keys(commits);
  console.log(
    `\nTotal unique commits since ${BASE_TAG}: ${allCommitHashes.length}`
  );

  // 3. Get version info using git describe (batched in parallel)
  async function getVersion(hash) {
    const describeOutput = await runAsync("git", [
      "describe",
      "--match",
      "v[0-9]*",
      "--",
      hash,
    ]);
    commits[hash].version = describeOutput
      .replace(/^v/, "")
      .replace(/-(\d+)-g[a-f0-9]+$/, " +$1");
  }

  console.log(`\nGetting version info in batches of ${BATCH_SIZE}...`);

  for (let i = 0; i < allCommitHashes.length; i += BATCH_SIZE) {
    const batch = allCommitHashes.slice(i, i + BATCH_SIZE);
    console.log(
      `Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(allCommitHashes.length / BATCH_SIZE)}...`
    );
    await Promise.all(batch.map(getVersion));
  }

  // 4. Fetch all refs (tags and branches)
  console.log("\nFetching refs...");

  const tags = {};
  const tagListResult = runOrFail("git", ["tag", "--list", "v[0-9]*"]);
  const tagList = tagListResult.stdout
    .trim()
    .split("\n")
    .filter((t) => t);

  for (const tag of tagList) {
    // Use ^{} to dereference annotated tags to their commit objects
    const result = runOrFail("git", ["rev-parse", `${tag}^{}`]);
    const commitHash = result.stdout.trim();

    // Only include tags that point to commits we've loaded
    if (commits[commitHash]) {
      tags[tag] = commitHash;
    }
  }

  console.log(
    `  Found ${Object.keys(tags).length} tags (filtered to loaded commits)`
  );

  const branchesObj = {};
  for (const branch of branches) {
    try {
      const result = runOrFail("git", ["rev-parse", branch]);
      branchesObj[branch] = result.stdout.trim();
    } catch {
      console.warn(`  Branch ${branch} not found, skipping`);
    }
  }

  console.log(`  Found ${Object.keys(branchesObj).length} branches`);

  // 5. Output JSON
  const output = {
    commits,
    refs: {
      tags,
      branches: branchesObj,
    },
    baseTag: BASE_TAG,
  };

  const outputPath = join(PROJECT_ROOT, "data/commits.json");
  mkdirSync(join(PROJECT_ROOT, "data"), { recursive: true });
  writeFileSync(outputPath, JSON.stringify(output, null, 2));

  console.log(
    `\nWritten ${Object.keys(commits).length} commits to ${outputPath}`
  );
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});
