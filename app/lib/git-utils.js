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

  get sortedRefs() {
    if (!this.commitData) return [];

    const refs = [];

    // Add branches first
    Object.keys(this.commitData.refs.branches).forEach((branch) => {
      refs.push({ value: branch, label: branch, type: 'branch' });
    });

    // Add tags sorted in descending order
    const tags = Object.keys(this.commitData.refs.tags).sort((a, b) => {
      const aVersion = semver.coerce(a);
      const bVersion = semver.coerce(b);
      if (aVersion && bVersion) {
        return semver.rcompare(aVersion, bVersion);
      }
      return b.localeCompare(a);
    });

    tags.forEach((tag) => {
      refs.push({ value: tag, label: tag, type: 'tag' });
    });

    return refs;
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

// Extract commit type from subject
export function getCommitType(subject) {
  const match = subject.match(/^(FEATURE|FIX|PERF|UX|A11Y|SECURITY|DEV):/);
  return match ? match[1] : null;
}
