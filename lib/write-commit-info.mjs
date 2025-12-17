import { execaSync, execa } from 'execa';
import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

// Get project root directory
const __dirname = dirname(fileURLToPath(import.meta.url));
const PROJECT_ROOT = join(__dirname, '..');
const REPO_DIR = join(PROJECT_ROOT, 'tmp/discourse-repo');
const BASE_TAG = 'v3.4.0';
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

const ORIGIN = 'https://github.com/discourse/discourse';
const FETCH_REFSPECS = [
  '+refs/heads/main:refs/heads/main',
  '+refs/heads/latest:refs/heads/latest',
  '+refs/heads/stable:refs/heads/stable',
  '+refs/heads/version/*:refs/heads/version/*',
  '+refs/tags/*:refs/tags/*',
];

async function main() {
  mkdirSync(REPO_DIR, { recursive: true });

  runOrFail('git', ['init', '--bare', '.']);
  runOrFail('git', [
    'fetch',
    ORIGIN,
    '--prune',
    "--refmap=''",
    ...FETCH_REFSPECS,
  ]);

  // 1. Collect all unique commits from all branches since BASE_TAG
  const branches = ['main', 'stable', 'beta', 'latest'];
  const allCommitHashesSet = new Set();

  console.log(`Collecting commits from branches: ${branches.join(', ')}`);

  for (const branch of branches) {
    try {
      const result = await runAsync('git', [
        'rev-list',
        `${BASE_TAG}..${branch}`,
      ]);
      const hashes = result.split('\n').filter((h) => h.trim());
      hashes.forEach((hash) => allCommitHashesSet.add(hash.trim()));
      console.log(`  ${branch}: ${hashes.length} commits`);
    } catch (error) {
      console.warn(`  ${branch}: not found or error, skipping`);
    }
  }

  const allCommitHashes = [...allCommitHashesSet];
  console.log(
    `\nTotal unique commits since ${BASE_TAG}: ${allCommitHashes.length}`,
  );

  // 2. Process each commit to get full info including parents
  const commits = {};
  const FIELD_SEP = '%x1f';

  async function processCommit(hash) {
    const format = `--format=%H${FIELD_SEP}%P${FIELD_SEP}%an${FIELD_SEP}%cI${FIELD_SEP}%s`;

    const info = await runAsync('git', ['show', format, '--no-patch', hash]);
    const fields = info.split('\x1f');

    const commitHash = fields[0]?.trim() || '';
    const parents = fields[1]?.trim() || '';
    const author = fields[2]?.trim() || '';
    const date = fields[3]?.trim() || '';
    const subject = fields[4]?.trim() || '';

    // Calculate version using git describe
    const describeOutput = await runAsync('git', [
      'describe',
      '--match',
      'v[0-9]*',
      '--',
      hash,
    ]);
    const version = describeOutput
      .replace(/^v/, '')
      .replace(/-(\d+)-g[a-f0-9]+$/, ' +$1');

    commits[commitHash] = {
      hash: commitHash,
      parents: parents.split(' ').filter((p) => p),
      author,
      date,
      subject,
      version,
    };
  }

  console.log(`\nProcessing commits in batches of ${BATCH_SIZE}...`);

  // Process commits in batches
  for (let i = 0; i < allCommitHashes.length; i += BATCH_SIZE) {
    const batch = allCommitHashes.slice(i, i + BATCH_SIZE);
    console.log(
      `Processing batch ${Math.floor(i / BATCH_SIZE) + 1}/${Math.ceil(allCommitHashes.length / BATCH_SIZE)}...`,
    );
    await Promise.all(batch.map(processCommit));
  }

  // 3. Fetch all refs (tags and branches)
  console.log('\nFetching refs...');

  const tags = {};
  const tagListResult = runOrFail('git', ['tag', '--list', 'v[0-9]*']);
  const tagList = tagListResult.stdout
    .trim()
    .split('\n')
    .filter((t) => t);

  for (const tag of tagList) {
    const result = runOrFail('git', ['rev-parse', tag]);
    tags[tag] = result.stdout.trim();
  }

  console.log(`  Found ${Object.keys(tags).length} tags`);

  const branchesObj = {};
  for (const branch of branches) {
    try {
      const result = runOrFail('git', ['rev-parse', branch]);
      branchesObj[branch] = result.stdout.trim();
    } catch (e) {
      console.warn(`  Branch ${branch} not found, skipping`);
    }
  }

  console.log(`  Found ${Object.keys(branchesObj).length} branches`);

  // 4. Output JSON
  const output = {
    commits,
    refs: {
      tags,
      branches: branchesObj,
    },
    baseTag: BASE_TAG,
  };

  const outputPath = join(PROJECT_ROOT, 'data/commits.json');
  mkdirSync(join(PROJECT_ROOT, 'data'), { recursive: true });
  writeFileSync(outputPath, JSON.stringify(output, null, 2));

  console.log(
    `\nWritten ${Object.keys(commits).length} commits to ${outputPath}`,
  );
}

main().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});
