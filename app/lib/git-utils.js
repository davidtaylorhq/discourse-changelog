// Resolve a ref (tag/branch/hash) to a commit hash
export function resolveRef(commitData, ref) {
  if (!commitData) return ref;

  // Check if it's a tag
  if (commitData.refs.tags[ref]) {
    return commitData.refs.tags[ref];
  }

  // Check if it's a branch
  if (commitData.refs.branches[ref]) {
    return commitData.refs.branches[ref];
  }

  // Check if it's a partial hash
  if (ref.length < 40) {
    const fullHash = Object.keys(commitData.commits).find((h) =>
      h.startsWith(ref)
    );
    return fullHash || ref;
  }

  // Otherwise assume it's a full hash
  return ref;
}

// Iterative traversal to find all commits reachable from a given commit
export function traverseParents(commitData, commitHash) {
  if (!commitData) return new Set();

  const visited = new Set();
  const queue = [commitHash];

  while (queue.length > 0) {
    const currentHash = queue.shift();

    // Skip if already visited or not in our dataset
    if (
      !currentHash ||
      visited.has(currentHash) ||
      !commitData.commits[currentHash]
    ) {
      continue;
    }

    visited.add(currentHash);
    const commit = commitData.commits[currentHash];

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
export function getCommitsBetween(commitData, startRef, endRef) {
  if (!commitData) return [];

  // Resolve refs to commit hashes
  const startHash = resolveRef(commitData, startRef);
  const endHash = resolveRef(commitData, endRef);

  // Build set of all commits reachable from startRef (exclusive set)
  const reachableFromStart = traverseParents(commitData, startHash);

  // Build set of all commits reachable from endRef (inclusive set)
  const reachableFromEnd = traverseParents(commitData, endHash);

  // Difference: commits in endRef but not in startRef
  const betweenSet = new Set(
    [...reachableFromEnd].filter((hash) => !reachableFromStart.has(hash))
  );

  // Convert to commit objects
  return [...betweenSet]
    .map((hash) => commitData.commits[hash])
    .filter((c) => c);
}

// Extract commit type from subject
export function getCommitType(subject) {
  const match = subject.match(/^(FEATURE|FIX|PERF|UX|A11Y|SECURITY|DEV):/);
  return match ? match[1] : null;
}
