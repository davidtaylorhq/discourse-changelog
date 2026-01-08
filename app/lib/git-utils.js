import { tracked } from "@glimmer/tracking";
import CommitsData from "/data/commits.json";
import NewFeaturesData from "/data/new-features.json";
import SecurityAdvisoriesData from "/data/security-advisories.json";
import semver from "semver";

export class AmbiguousRefError extends Error {
  constructor(ref, matches) {
    const shortMatches = matches.slice(0, 5).map((h) => h.slice(0, 12));
    const moreCount = matches.length - 5;
    const matchList =
      moreCount > 0
        ? `${shortMatches.join(", ")} and ${moreCount} more`
        : shortMatches.join(", ");

    super(
      `Ambiguous ref '${ref}' matches ${matches.length} commits: ${matchList}. Use more characters to be specific.`
    );
    this.name = "AmbiguousRefError";
    this.ref = ref;
    this.matches = matches;
  }
}

export class UnknownRefError extends Error {
  constructor(ref) {
    super(`Unknown ref '${ref}'. No matching tag, branch, or commit found.`);
    this.name = "UnknownRefError";
    this.ref = ref;
  }
}

export class ChangelogData {
  @tracked commitData = CommitsData;
  @tracked newFeatures = NewFeaturesData;
  @tracked securityAdvisories = SecurityAdvisoriesData;

  get baseTag() {
    return this.commitData?.baseTag || "";
  }

  get defaultStartRef() {
    return this.sortedTags[0]?.value || "";
  }

  get defaultEndRef() {
    return "latest";
  }

  get totalCommits() {
    return this.commitData ? Object.keys(this.commitData.commits).length : 0;
  }

  get branches() {
    if (!this.commitData) {
      return [];
    }
    return Object.keys(this.commitData.refs.branches).map((branch) => ({
      value: branch,
      label: branch,
    }));
  }

  get sortedTags() {
    if (!this.commitData) {
      return [];
    }

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
    if (!this.commitData) {
      return [];
    }

    const refs = [];

    // Add branches first
    this.branches.forEach((branch) => {
      refs.push({ ...branch, type: "branch" });
    });

    // Add tags
    this.sortedTags.forEach((tag) => {
      refs.push({ ...tag, type: "tag" });
    });

    return refs;
  }

  // Get the previous version tag from a given ref
  // Traverses git history to find the most recent tag in the parent commits
  getPreviousVersion(ref) {
    if (!this.commitData) {
      return null;
    }

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
    if (!this.commitData) {
      return ref;
    }

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
      const matches = Object.keys(this.commitData.commits).filter((h) =>
        h.startsWith(ref)
      );

      if (matches.length > 1) {
        throw new AmbiguousRefError(ref, matches);
      }

      if (matches.length === 0) {
        throw new UnknownRefError(ref);
      }

      return matches[0];
    }

    // Full hash - verify it exists
    if (!this.commitData.commits[ref]) {
      throw new UnknownRefError(ref);
    }

    return ref;
  }

  // Iterative traversal to find all commits reachable from a given commit
  traverseParents(commitHash) {
    if (!this.commitData) {
      return new Set();
    }

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
    if (!this.commitData) {
      return [];
    }

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
  return version.replace(/\.beta(\d+)$/, "-beta.$1");
}

// Parse a version string to a semver object, handling beta notation
export function parseVersion(version) {
  const normalized = normalizeVersion(version);
  return semver.parse(normalized);
}

export const COMMIT_TYPES = [
  { key: "FEATURE", label: "Feature", color: "#27ae60", prefix: "FEATURE" },
  { key: "FIX", label: "Fix", color: "#c0392b", prefix: "FIX" },
  { key: "PERF", label: "Performance", color: "#8e44ad", prefix: "PERF" },
  { key: "UX", label: "UX", color: "#2980b9", prefix: "UX" },
  { key: "A11Y", label: "Accessibility", color: "#16a085", prefix: "A11Y" },
  { key: "SECURITY", label: "Security", color: "#d35400", prefix: "SECURITY" },
  {
    key: "TRANSLATIONS",
    label: "Translations",
    color: "#e91e63",
    prefix: "I18N",
  },
  { key: "DEV", label: "Dev", color: "#7f8c8d", prefix: "DEV" },
  { key: "DEPS", label: "Dependencies", color: "#7f8c8d", prefix: "DEPS" },
  { key: "OTHER", label: "Other", color: "#95a5a6" },
];

// Extract commit type from subject
export function getCommitType(subject) {
  for (const type of COMMIT_TYPES) {
    if (type.prefix && subject.startsWith(`${type.prefix}:`)) {
      return type.key;
    }
  }

  // Handle legacy formats
  if (subject.startsWith("Update translations")) {
    return "TRANSLATIONS";
  }
  if (subject.startsWith("Build(deps")) {
    return "DEPS";
  }

  return "OTHER";
}

// Sort commits by date
export function sortCommitsByDate(commits, direction = "desc") {
  return [...commits].sort((a, b) => {
    const dateA = new Date(a.date);
    const dateB = new Date(b.date);
    return direction === "desc" ? dateB - dateA : dateA - dateB;
  });
}

// Count commits by type
export function countCommitsByType(commits) {
  const counts = {};
  COMMIT_TYPES.forEach((type) => (counts[type.key] = 0));

  commits.forEach((commit) => {
    const type = getCommitType(commit.subject);
    if (type && counts[type] !== undefined) {
      counts[type]++;
    } else {
      counts["OTHER"]++;
    }
  });

  return counts;
}

// Filter commits by type and/or search term
export function filterCommits(commits, { type, searchTerm } = {}) {
  let filtered = commits;

  if (type && type !== "all") {
    filtered = filtered.filter((commit) => {
      const commitType = getCommitType(commit.subject) || "OTHER";
      return commitType === type;
    });
  }

  if (searchTerm?.trim()) {
    const term = searchTerm.toLowerCase();
    filtered = filtered.filter((commit) =>
      commit.subject.toLowerCase().includes(term)
    );
  }

  return filtered;
}

// Get version range from commits
function getVersionRange(commits) {
  if (!commits.length) {
    return { newest: null, oldest: null };
  }
  const sorted = sortCommitsByDate(commits, "desc");
  return {
    newest: parseVersion(sorted[0].version?.replace(/\s*\+\d+$/, "")),
    oldest: parseVersion(sorted.at(-1).version?.replace(/\s*\+\d+$/, "")),
  };
}

// Check if a version falls within a range (exclusive start, inclusive end)
function versionInRange(version, oldest, newest) {
  const parsed = parseVersion(version);
  if (!parsed || !newest || !oldest) {
    return false;
  }
  return semver.gt(parsed, oldest) && semver.lte(parsed, newest);
}

// Filter features that fall within a commit range
export function filterFeaturesByCommits(features, commits, resolveRef) {
  if (!commits.length || !features.length) {
    return [];
  }

  const commitHashes = new Set(commits.map((c) => c.hash));
  const { newest, oldest } = getVersionRange(commits);

  return features.filter((feature) => {
    const discourseVersion = feature.discourse_version;
    if (!discourseVersion) {
      return false;
    }

    if (discourseVersion.match(/\d+\.\d+\.\d+/)) {
      return versionInRange(discourseVersion, oldest, newest);
    } else {
      const fullCommitHash = resolveRef(discourseVersion);
      return commitHashes.has(fullCommitHash);
    }
  });
}

// Filter security advisories that have a patched version in the commit range
export function filterAdvisoriesByCommits(advisories, commits) {
  if (!commits.length || !advisories.length) {
    return [];
  }

  const { newest, oldest } = getVersionRange(commits);

  return advisories.filter((advisory) => {
    // Check if any patched version falls within the range
    return advisory.patched_versions?.some((version) =>
      versionInRange(version, oldest, newest)
    );
  });
}
