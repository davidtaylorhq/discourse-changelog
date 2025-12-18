import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { ChangelogData } from '../lib/git-utils.js';
import semver from 'semver';

export default class VersionsTable extends Component {
  @tracked data = new ChangelogData();

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    try {
      await this.data.load();
    } catch (error) {
      console.error('Failed to load data:', error);
    }
  }

  get versions() {
    if (!this.data.commitData) return [];

    // Get all tags and their commit info
    const versions = [];
    for (const [tagName, tagHash] of Object.entries(this.data.commitData.refs.tags)) {
      // Skip tags ending with -latest
      if (tagName.endsWith('-latest')) continue;

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
    const versions = this.versions;
    const groups = new Map();

    // Group versions by major.minor
    versions.forEach(v => {
      const parsed = semver.coerce(v.version);
      if (!parsed) return;

      const minorKey = `${parsed.major}.${parsed.minor}`;
      if (!groups.has(minorKey)) {
        groups.set(minorKey, {
          minorVersion: minorKey,
          versions: [],
          latestSemver: parsed,
          firstReleaseVersion: null,
        });
      }

      const group = groups.get(minorKey);
      group.versions.push({
        ...v,
        parsed,
      });
      // Keep track of the latest version in this group
      if (semver.gt(parsed, group.latestSemver)) {
        group.latestSemver = parsed;
      }
    });

    // Convert to array and sort by semver descending
    const result = Array.from(groups.values());
    result.sort((a, b) => semver.rcompare(a.latestSemver, b.latestSemver));

    // Sort versions within each group by semver descending
    result.forEach(group => {
      group.versions.sort((a, b) => semver.rcompare(a.parsed, b.parsed));

      // Find the .0 version for the group header
      const dotZeroVersion = group.versions.find(v => {
        const match = v.version.match(/^v?\d+\.\d+\.0$/);
        return match;
      });
      group.headerVersion = dotZeroVersion || group.versions[0];
    });

    return result;
  }

  formatDate(isoString) {
    const date = new Date(isoString);
    return date.toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
    });
  }

  <template>
    <div class="versions-container">
      <div class="header">
        <h1>Discourse Changelog</h1>
        <p>Browse the release history and changes for Discourse</p>
      </div>

      {{#if this.data.isLoading}}
        <div class="loading">Loading versions...</div>
      {{else}}
        <table class="versions-table">
          <thead>
            <tr>
              <th>Version</th>
              <th>Released</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.groupedVersions as |group|}}
              <tr class="minor-version">
                <td>
                  <a href="/changelog?end={{group.headerVersion.version}}">v{{group.minorVersion}}.x</a>
                </td>
                <td>{{this.formatDate group.headerVersion.date}}</td>
              </tr>
              {{#each group.versions as |v|}}
                <tr class="indented">
                  <td>
                    <a href="/changelog?end={{v.version}}">{{v.version}}</a>
                  </td>
                  <td>{{this.formatDate v.date}}</td>
                </tr>
              {{/each}}
            {{/each}}
          </tbody>
        </table>
      {{/if}}
    </div>

    <style>
      .versions-container {
        max-width: 900px;
        margin: 0 auto;
        padding: 2rem 1rem;
      }

      .header {
        margin-bottom: 3rem;
        text-align: center;
      }

      .header h1 {
        font-size: 2.5rem;
        margin-bottom: 0.5rem;
      }

      .header p {
        color: #666;
        font-size: 1.1rem;
      }

      .loading {
        text-align: center;
        padding: 2rem;
        color: #666;
      }

      .versions-table {
        width: 100%;
        border-collapse: collapse;
        background: white;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        border-radius: 8px;
        overflow: hidden;
      }

      .versions-table thead {
        background: #f7f7f7;
      }

      .versions-table th {
        text-align: left;
        padding: 1rem 1.5rem;
        font-weight: 600;
        color: #333;
        border-bottom: 2px solid #e0e0e0;
      }

      .versions-table td {
        padding: 1rem 1.5rem;
        border-bottom: 1px solid #f0f0f0;
      }

      .versions-table tbody tr:hover {
        background: #fafafa;
      }

      .versions-table a {
        color: #0066cc;
        text-decoration: none;
        font-weight: 500;
      }

      .versions-table a:hover {
        text-decoration: underline;
      }

      .versions-table tr.minor-version {
        font-weight: 600;
        background: #f7f7f7;
      }

      .versions-table tr.indented td:first-child {
        padding-left: 3rem;
      }

      .versions-table tr.indented {
        font-size: 0.95em;
      }
    </style>
  </template>
}
