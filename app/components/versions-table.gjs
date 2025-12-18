import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { on } from '@ember/modifier';
import { fn, get } from '@ember/helper';
import { ChangelogData } from '../lib/git-utils.js';
import semver from 'semver';

const eq = (a, b) => a === b;

export default class VersionsTable extends Component {
  @tracked data = new ChangelogData();
  @tracked versionSupport = [];
  @tracked expandedVersions = new Set();

  constructor() {
    super(...arguments);
    this.loadData();
  }

  async loadData() {
    try {
      await this.data.load();
      const supportModule = await import('/data/version-support.json');
      this.versionSupport = supportModule.default;
    } catch (error) {
      console.error('Failed to load data:', error);
    }
  }

  get versions() {
    if (!this.data.commitData) return [];

    // Get all tags and their commit info
    const versions = [];
    for (const [tagName, tagHash] of Object.entries(
      this.data.commitData.refs.tags
    )) {
      // Skip tags ending with -latest
      if (tagName.endsWith('-latest')) continue;

      // Skip beta versions
      if (tagName.includes('beta')) continue;

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
    this.versionSupport.forEach((supportEntry) => {
      // Extract the display version (with leading zeros preserved)
      const displayMatch = supportEntry.version.match(/v?(\d+\.\d+)/);
      const displayMinorKey = displayMatch ? displayMatch[1] : null;

      if (!displayMinorKey) return;

      // Normalize version for semver parsing
      // Add .0 patch version if not present, and remove leading zeros in minor
      let normalizedVersion = supportEntry.version.replace(/^v/, ''); // Remove v prefix
      if (!/\.\d+$/.test(normalizedVersion) || normalizedVersion.split('.').length === 2) {
        normalizedVersion += '.0'; // Add .0 patch version
      }
      normalizedVersion = normalizedVersion.replace(/\.0(\d)/, '.$1'); // Remove leading zeros
      const parsed = semver.coerce(normalizedVersion);

      if (!parsed) return;

      const group = {
        minorVersion: displayMinorKey,
        supportInfo: supportEntry,
        versions: [],
        latestSemver: parsed,
      };

      // If this is an upcoming or in-development version, just add the placeholder
      if (supportEntry.status === 'upcoming' || supportEntry.status === 'in-development') {
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
          if (!vParsed) return false;
          // Match major.minor
          return vParsed.major === parsed.major && vParsed.minor === parsed.minor;
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
      const [year, month] = isoString.split('-');
      const date = new Date(year, parseInt(month) - 1, 1);
      return date.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'long'
      });
    }

    // Otherwise it's yyyy-mm-dd format
    const date = new Date(isoString);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  getRelativeTime(isoString) {
    const date = new Date(isoString);
    const now = new Date();
    const diffInMs = now - date;
    const diffInDays = Math.floor(diffInMs / (1000 * 60 * 60 * 24));

    if (diffInDays === 0) {
      return 'today';
    } else if (diffInDays === 1) {
      return '1 day ago';
    } else if (diffInDays < 30) {
      return `${diffInDays} days ago`;
    } else if (diffInDays < 60) {
      return '1 month ago';
    } else if (diffInDays < 365) {
      const months = Math.floor(diffInDays / 30);
      return `${months} months ago`;
    } else if (diffInDays < 730) {
      return '1 year ago';
    } else {
      const years = Math.floor(diffInDays / 365);
      return `${years} years ago`;
    }
  }

  @action
  toggleExpanded(minorVersion) {
    if (this.expandedVersions.has(minorVersion)) {
      this.expandedVersions.delete(minorVersion);
    } else {
      this.expandedVersions.add(minorVersion);
    }
    this.expandedVersions = new Set(this.expandedVersions); // Trigger reactivity
  }

  @action
  isExpanded(minorVersion) {
    return this.expandedVersions.has(minorVersion);
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
              <th>Release</th>
              <th>Released</th>
              <th>Latest Version</th>
              <th>End of Life</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {{#each this.groupedVersions as |group|}}
              <tr class="minor-version {{if (eq group.supportInfo.status 'upcoming') 'upcoming-version'}} {{if (eq group.supportInfo.status 'in-development') 'in-development-version'}} {{if (eq group.supportInfo.status 'active') 'active-version'}} {{if (eq group.supportInfo.status 'end-of-life') 'eol-version'}} {{if group.supportInfo.isESR 'esr-version'}}">
                <td>
                  {{#if (eq group.supportInfo.status "in-development")}}
                    <a href="/changelog?end=latest">v{{group.minorVersion}}</a>
                  {{else if (eq group.supportInfo.status "upcoming")}}
                    <span class="upcoming-version-text">v{{group.minorVersion}}</span>
                  {{else}}
                    <button type="button" class="expand-button" {{on "click" (fn this.toggleExpanded group.minorVersion)}}>
                      <span class="caret {{if (this.isExpanded group.minorVersion) 'expanded'}}">▶</span>
                    </button>
                    <a
                      href="/changelog?end={{group.headerVersion.version}}"
                    >v{{group.minorVersion}}</a>
                  {{/if}}
                </td>
                <td>
                  {{#if (eq group.supportInfo.status "in-development")}}
                    <span class="upcoming-date">{{this.formatDate group.headerVersion.date}}</span>
                  {{else if (eq group.supportInfo.status "upcoming")}}
                    <span class="upcoming-date">{{this.formatDate group.headerVersion.date}}</span>
                  {{else}}
                    <span class="relative-date">
                      {{this.getRelativeTime group.headerVersion.date}}
                      <span class="date-badge">{{this.formatDate group.headerVersion.date}}</span>
                    </span>
                  {{/if}}
                </td>
                <td>
                  {{#if (eq group.supportInfo.status "in-development")}}
                    <a href="/changelog?end=latest">v{{group.minorVersion}}.0-latest</a>
                  {{else if (eq group.supportInfo.status "upcoming")}}
                    <span class="upcoming-version-text">—</span>
                  {{else if (get group.versions "0")}}
                    <a href="/changelog?end={{get (get group.versions "0") "version"}}">{{get (get group.versions "0") "version"}}</a>
                  {{/if}}
                </td>
                <td>
                  {{#if group.supportInfo.supportEndDate}}
                    {{this.formatDate group.supportInfo.supportEndDate}}
                  {{else}}
                    —
                  {{/if}}
                </td>
                <td>
                  <span
                    class="support-status support-status-{{group.supportInfo.status}}"
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
                    {{#if group.supportInfo.isESR}}
                      <span class="esr-text"> (ESR)</span>
                    {{/if}}
                  </span>
                </td>
              </tr>
              {{#if (this.isExpanded group.minorVersion)}}
                {{#each group.versions as |v|}}
                  {{#unless v.isUpcoming}}
                    <tr class="indented">
                      <td colspan="2">
                        <a href="/changelog?end={{v.version}}">{{v.version}}</a>
                      </td>
                      <td>
                        <span class="relative-date">
                          {{this.getRelativeTime v.date}}
                          <span class="date-badge">{{this.formatDate v.date}}</span>
                        </span>
                      </td>
                      <td></td>
                      <td></td>
                    </tr>
                  {{/unless}}
                {{/each}}
              {{/if}}
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
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
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

      .versions-table tr.minor-version td:nth-child(2),
      .versions-table tr.minor-version td:nth-child(4) {
        font-weight: normal;
      }

      .versions-table tr.eol-version {
        background: #f5f5f5 !important;
        color: #999;
      }

      .versions-table tr.eol-version a {
        color: #999;
      }

      .versions-table tr.active-version {
        background: #f0f9f4 !important;
      }

      .versions-table tr.active-version.esr-version {
        background: #f3e5f5 !important;
      }

      .versions-table tr.in-development-version {
        background: #e8f5ee !important;
      }

      .versions-table tr.upcoming-version {
        background: #f0f8ff !important;
      }

      .expand-button {
        background: none;
        border: none;
        padding: 0;
        margin-right: 0.5rem;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        width: 20px;
        height: 20px;
        vertical-align: middle;
      }

      .expand-button:hover {
        opacity: 0.7;
      }

      .caret {
        display: inline-block;
        transition: transform 0.2s;
        font-size: 0.7rem;
        color: #666;
      }

      .caret.expanded {
        transform: rotate(90deg);
      }

      .versions-table tr.indented td:first-child {
        padding-left: 3rem;
      }

      .versions-table tr.indented {
        font-size: 0.95em;
      }

      .eol-version + .indented,
      .eol-version ~ .indented {
        background: #f5f5f5;
        color: #999;
      }

      .eol-version ~ .indented a {
        color: #999;
      }

      .active-version:not(.esr-version) ~ .indented {
        background: #f0f9f4;
      }

      .active-version.esr-version ~ .indented {
        background: #f3e5f5;
      }

      .in-development-version ~ .indented {
        background: #e8f5ee;
      }

      .upcoming-version ~ .indented {
        background: #f0f8ff;
      }

      .esr-text {
        color: #666;
        font-weight: normal;
      }

      .support-status {
        font-size: 0.9rem;
        font-weight: 600;
      }

      .support-status-active {
        color: #27ae60;
      }

      .support-status-end-of-life {
        color: #95a5a6;
      }

      .support-status-upcoming {
        color: #3498db;
      }

      .support-status-in-development {
        color: #27ae60;
      }

      .active-version.esr-version .support-status {
        color: #9b59b6;
      }

      .upcoming-version-text {
        font-weight: 600;
        color: #555;
      }

      .upcoming-date {
        color: #3498db;
        font-style: italic;
      }

      .relative-date {
        display: flex;
        align-items: center;
        gap: 0.5rem;
      }

      .date-badge {
        display: inline-block;
        padding: 0.15rem 0.5rem;
        background: #f0f0f0;
        color: #666;
        font-size: 0.8rem;
        border-radius: 3px;
        font-weight: normal;
      }

      .in-development-version {
        background: #f3e5f5 !important;
      }

      .in-development-date {
        color: #9b59b6;
      }
    </style>
  </template>
}
