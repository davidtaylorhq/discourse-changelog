import { tracked } from '@glimmer/tracking';
import semver from 'semver';

export class ChangelogData {
  @tracked commitData = null;
  @tracked newFeatures = [];
  @tracked isLoading = false;

  async load() {
    this.isLoading = true;
    try {
      const [commitsModule, featuresModule] = await Promise.all([
        import('/data/commits.json'),
        import('/data/new-features.json'),
      ]);
      this.commitData = commitsModule.default;
      this.newFeatures = featuresModule.default;
    } finally {
      this.isLoading = false;
    }
  }

  get baseTag() {
    return this.commitData?.baseTag || '';
  }

  get totalCommits() {
    return this.commitData ? Object.keys(this.commitData.commits).length : 0;
  }

  get branches() {
    if (!this.commitData) return [];
    return Object.keys(this.commitData.refs.branches).map((branch) => ({
      value: branch,
      label: branch,
    }));
  }

  get sortedTags() {
    if (!this.commitData) return [];

    // Sort tags in descending order
    const tags = Object.keys(this.commitData.refs.tags).sort((a, b) => {
      const aNormalized = normalizeVersion(a);
      const bNormalized = normalizeVersion(b);

      const aVersion = semver.valid(aNormalized);
      const bVersion = semver.valid(bNormalized);

      if (aVersion && bVersion) {
        return semver.rcompare(aVersion, bVersion);
      }

      // If semver parsing fails, fall back to string comparison
      return b.localeCompare(a);
    });

    return tags.map((tag) => ({ value: tag, label: tag }));
  }

  get sortedRefs() {
    if (!this.commitData) return [];

    const refs = [];

    // Add branches first
    this.branches.forEach((branch) => {
      refs.push({ ...branch, type: 'branch' });
    });

    // Add tags
    this.sortedTags.forEach((tag) => {
      refs.push({ ...tag, type: 'tag' });
    });

    return refs;
  }

  // Get the previous version tag from a given ref
  // Traverses git history to find the most recent tag in the parent commits
  getPreviousVersion(ref) {
    if (!this.commitData) return null;

    // Resolve the ref to a commit hash
    const commitHash = this.resolveRef(ref);
    if (!this.commitData.commits[commitHash]) {
      return null;
    }

    // Get all parent commits (excluding the ref itself)
    const parentCommits = this.traverseParents(commitHash);
    parentCommits.delete(commitHash);

    if (parentCommits.size === 0) {
      return null;
    }

    // Only consider tags from sortedTags (which excludes filtered tags like -latest)
    const validTagValues = this.sortedTags.map((t) => t.value);

    // Find all valid tags that point to parent commits
    const matchingTags = [];
    for (const tagName of validTagValues) {
      const tagHash = this.commitData.refs.tags[tagName];
      if (tagHash && parentCommits.has(tagHash)) {
        matchingTags.push(tagName);
      }
    }

    if (matchingTags.length === 0) {
      return null;
    }

    // sortedTags is already sorted, so just return the first match
    // (since we iterate validTagValues in sorted order, matchingTags is also sorted)
    return matchingTags[0];
  }

  // Resolve a ref (tag/branch/hash) to a commit hash
  resolveRef(ref) {
    if (!this.commitData) return ref;

    // Check if it's a tag
    if (this.commitData.refs.tags[ref]) {
      return this.commitData.refs.tags[ref];
    }

    // Check if it's a branch
    if (this.commitData.refs.branches[ref]) {
      return this.commitData.refs.branches[ref];
    }

    // Check if it's a partial hash
    if (ref.length < 40) {
      const fullHash = Object.keys(this.commitData.commits).find((h) =>
        h.startsWith(ref)
      );
      return fullHash || ref;
    }

    // Otherwise assume it's a full hash
    return ref;
  }

  // Iterative traversal to find all commits reachable from a given commit
  traverseParents(commitHash) {
    if (!this.commitData) return new Set();

    const visited = new Set();
    const queue = [commitHash];

    while (queue.length > 0) {
      const currentHash = queue.shift();

      // Skip if already visited or not in our dataset
      if (
        !currentHash ||
        visited.has(currentHash) ||
        !this.commitData.commits[currentHash]
      ) {
        continue;
      }

      visited.add(currentHash);
      const commit = this.commitData.commits[currentHash];

      // Add parents to queue
      if (commit.parents) {
        commit.parents.forEach((parentHash) => {
          if (!visited.has(parentHash)) {
            queue.push(parentHash);
          }
        });
      }
    }

    return visited;
  }

  // Get commits between two refs
  getCommitsBetween(startRef, endRef) {
    if (!this.commitData) return [];

    // Resolve refs to commit hashes
    const startHash = this.resolveRef(startRef);
    const endHash = this.resolveRef(endRef);

    // Build set of all commits reachable from startRef (exclusive set)
    const reachableFromStart = this.traverseParents(startHash);

    // Build set of all commits reachable from endRef (inclusive set)
    const reachableFromEnd = this.traverseParents(endHash);

    // Difference: commits in endRef but not in startRef
    const betweenSet = new Set(
      [...reachableFromEnd].filter((hash) => !reachableFromStart.has(hash))
    );

    // Convert to commit objects
    return [...betweenSet]
      .map((hash) => this.commitData.commits[hash])
      .filter((c) => c);
  }
}

// Normalize version tags to proper semver format
// v3.5.0.beta1 -> v3.5.0-beta.1
export function normalizeVersion(version) {
  return version.replace(/\.beta(\d+)$/, '-beta.$1');
}

// Parse a version string to a semver object, handling beta notation
export function parseVersion(version) {
  const normalized = normalizeVersion(version);
  return semver.parse(normalized);
}

// Extract commit type from subject
export function getCommitType(subject) {
  // Check for explicit type prefix
  const match = subject.match(/^(FEATURE|FIX|PERF|UX|A11Y|SECURITY|DEV):/);
  if (match) return match[1];

  // Check for special patterns
  if (subject.startsWith('Update translations')) return 'TRANSLATIONS';
  if (subject.startsWith('Build(deps')) return 'DEV';

  return null;
}
