import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import "./versions-table.css";
import VersionSupport from "/data/version-support.json";
import semver from "semver";
import eq from "../../helpers/eq.js";
import { ChangelogData } from "../../lib/git-utils.js";
import VersionsTimeline from "./timeline";

export default class VersionsTable extends Component {
  @tracked data = new ChangelogData();

  @tracked versionSupport = [];

  get versions() {
    if (!this.data.commitData) {
      return [];
    }

    // Get all tags and their commit info
    const versions = [];
    for (const [tagName, tagHash] of Object.entries(
      this.data.commitData.refs.tags
    )) {
      // Skip tags ending with -latest
      if (tagName.endsWith("-latest")) {
        continue;
      }

      // Skip beta versions
      if (tagName.includes("beta")) {
        continue;
      }

      const commit = this.data.commitData.commits[tagHash];
      if (commit) {
        versions.push({
          version: tagName,
          date: commit.date,
          hash: tagHash,
        });
      }
    }

    // Sort by date descending (newest first)
    versions.sort((a, b) => new Date(b.date) - new Date(a.date));

    return versions;
  }

  get groupedVersions() {
    const groups = [];

    // Use version-support.json as the source of truth
    VersionSupport.forEach((supportEntry) => {
      const parsed = semver.coerce(supportEntry.version);

      if (!parsed) {
        return;
      }

      const group = {
        minorVersion: supportEntry.version,
        supportInfo: supportEntry,
        versions: [],
        latestSemver: parsed,
      };

      // If this is an upcoming or in-development version, just add the placeholder
      if (
        supportEntry.status === "upcoming" ||
        supportEntry.status === "in-development"
      ) {
        group.versions.push({
          version: supportEntry.version,
          date: supportEntry.releaseDate,
          hash: null,
          parsed,
          isUpcoming: true,
        });
        group.headerVersion = group.versions[0];
      } else {
        // For released versions, find all matching patch versions from git
        const gitVersions = this.versions;
        const matchingVersions = gitVersions.filter((v) => {
          const vParsed = semver.coerce(v.version);
          if (!vParsed) {
            return false;
          }
          // Match major.minor
          return (
            vParsed.major === parsed.major && vParsed.minor === parsed.minor
          );
        });

        // Add all matching versions
        matchingVersions.forEach((v) => {
          const vParsed = semver.coerce(v.version);
          group.versions.push({
            ...v,
            parsed: vParsed,
          });

          // Track latest
          if (semver.gt(vParsed, group.latestSemver)) {
            group.latestSemver = vParsed;
          }
        });

        // Sort versions by semver descending
        group.versions.sort((a, b) => semver.rcompare(a.parsed, b.parsed));

        // Find the .0 version for the group header
        const dotZeroVersion = group.versions.find((v) => {
          const match = v.version.match(/^v?\d+\.\d+\.0$/);
          return match;
        });
        group.headerVersion = dotZeroVersion || group.versions[0];

        // Override with the release date from version-support.json for consistency
        if (group.headerVersion && supportEntry.releaseDate) {
          group.headerVersion = {
            ...group.headerVersion,
            date: supportEntry.releaseDate,
          };
        }
      }

      groups.push(group);
    });

    // Sort groups by latest version descending
    groups.sort((a, b) => semver.rcompare(a.latestSemver, b.latestSemver));

    return groups;
  }

  formatDate(isoString) {
    // Check if it's yyyy-mm format (no day)
    if (/^\d{4}-\d{2}$/.test(isoString)) {
      const [year, month] = isoString.split("-");
      const date = new Date(year, parseInt(month, 10) - 1, 1);
      return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "long",
      });
    }

    // Otherwise it's yyyy-mm-dd format
    const date = new Date(isoString);
    return date.toLocaleDateString("en-US", {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  getRelativeTime(isoString) {
    const date = new Date(isoString);
    const now = new Date();
    const diffInMs = now - date;
    const diffInDays = Math.floor(diffInMs / (1000 * 60 * 60 * 24));

    if (diffInDays === 0) {
      return "today";
    } else if (diffInDays === 1) {
      return "1 day ago";
    } else if (diffInDays < 30) {
      return `${diffInDays} days ago`;
    } else if (diffInDays < 60) {
      return "1 month ago";
    } else if (diffInDays < 365) {
      const months = Math.floor(diffInDays / 30);
      return `${months} months ago`;
    } else if (diffInDays < 730) {
      return "1 year ago";
    } else {
      const years = Math.floor(diffInDays / 365);
      return `${years} years ago`;
    }
  }

  isPlannedDate(isoString) {
    if (!isoString) {
      return false;
    }

    // If it's yyyy-mm format (imprecise), always consider it "planned"
    if (/^\d{4}-\d{2}$/.test(isoString)) {
      return true;
    }

    // Otherwise it's yyyy-mm-dd format - check if it's in the future
    const date = new Date(isoString);
    const now = new Date();
    return date > now;
  }

  <template>
    <div class="versions-container">

      <div class="feedback-banner">
        <span class="feedback-icon">✨</span>
        <span>
          This site is new! Let us know what you think
          <a
            href="https://meta.discourse.org/t/392712"
            target="_blank"
            rel="noopener"
          >on Meta</a>.
        </span>
      </div>

      <div class="version-info">
        <p>
          This site provides information about Discourse versions, their release
          dates, support timelines, and changelogs.
        </p>
        <p>
          Most Discourse installations track the
          <strong>latest</strong>
          version, which receives continuous updates with new features, bug
          fixes, and security patches.
        </p>
        <p>
          Numbered releases are available for those who prefer less frequent
          changes. Each monthly release receives security updates for
          approximately two months. Every 6 months, an Extended Support Release
          (ESR) is designated, which receives updates for approximately 8
          months.
        </p>
      </div>

      <VersionsTimeline @versions={{this.groupedVersions}} />

      <div class="versions-cards">
        {{#each this.groupedVersions as |group|}}
          <div
            id="version-{{group.minorVersion}}"
            class="version-card
              {{if (eq group.supportInfo.status 'upcoming') 'upcoming-version'}}
              {{if
                (eq group.supportInfo.status 'in-development')
                'in-development-version'
              }}
              {{if (eq group.supportInfo.status 'active') 'active-version'}}
              {{if (eq group.supportInfo.status 'end-of-life') 'eol-version'}}"
          >
            <div class="card-header">
              <div class="version-title">
                {{#if (eq group.supportInfo.status "in-development")}}
                  <LinkTo
                    @route="changelog"
                    @model="latest"
                    class="version-link"
                  >v{{group.minorVersion}}</LinkTo>
                {{else if (eq group.supportInfo.status "upcoming")}}
                  <span class="version-name">v{{group.minorVersion}}</span>
                {{else}}
                  <LinkTo
                    @route="changelog"
                    @model={{group.headerVersion.version}}
                    class="version-link"
                  >v{{group.minorVersion}}</LinkTo>
                {{/if}}
                {{#each group.supportInfo.tags as |tag|}}
                  <span class="version-tag">{{tag}}</span>
                {{/each}}
              </div>
              <div
                class="status-badge support-status-{{group.supportInfo.status}}"
              >
                {{#if (eq group.supportInfo.status "in-development")}}
                  Active development
                {{else if (eq group.supportInfo.status "active")}}
                  Supported
                {{else if (eq group.supportInfo.status "end-of-life")}}
                  End of Life
                {{else if (eq group.supportInfo.status "upcoming")}}
                  Upcoming
                {{/if}}
              </div>
            </div>

            <div class="card-body">
              <div class="card-row">
                <div class="card-label">
                  {{#if (this.isPlannedDate group.headerVersion.date)}}
                    Planned release
                  {{else}}
                    First released
                  {{/if}}
                </div>
                <div class="card-value">
                  {{#if (eq group.supportInfo.status "in-development")}}
                    <span class="upcoming-date">{{this.formatDate
                        group.headerVersion.date
                      }}</span>
                  {{else if (eq group.supportInfo.status "upcoming")}}
                    <span class="upcoming-date">{{this.formatDate
                        group.headerVersion.date
                      }}</span>
                  {{else}}
                    <span class="relative-date">
                      {{this.getRelativeTime group.headerVersion.date}}
                      <span class="date-badge">{{this.formatDate
                          group.headerVersion.date
                        }}</span>
                    </span>
                  {{/if}}
                </div>
              </div>

              <div class="card-row">
                <div class="card-label">
                  {{#if (this.isPlannedDate group.supportInfo.supportEndDate)}}
                    Planned end of life
                  {{else}}
                    End of Life
                  {{/if}}
                </div>
                <div class="card-value">
                  {{#if group.supportInfo.supportEndDate}}
                    {{this.formatDate group.supportInfo.supportEndDate}}
                    {{#if group.supportInfo.isESR}}
                      <span class="esr-note">(ESR)</span>
                    {{/if}}
                  {{else}}
                    <span class="muted-text">—</span>
                  {{/if}}
                </div>
              </div>
            </div>

            {{#unless (eq group.supportInfo.status "upcoming")}}
              {{#unless (eq group.supportInfo.status "in-development")}}
                <div class="patch-versions">
                  {{#each group.versions as |v|}}
                    <div class="patch-version-row">
                      <LinkTo
                        @route="changelog"
                        @model={{v.version}}
                        class="patch-version-link"
                      >{{v.version}}</LinkTo>
                      <span class="relative-date">
                        {{this.getRelativeTime v.date}}
                        <span class="date-badge">{{this.formatDate
                            v.date
                          }}</span>
                      </span>
                    </div>
                  {{/each}}
                </div>
              {{/unless}}
            {{/unless}}
          </div>
        {{/each}}
      </div>
    </div>
  </template>
}
