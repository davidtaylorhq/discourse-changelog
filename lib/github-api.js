/**
 * GitHub API client for fetching commit data
 */
export class GitHubAPI {
  constructor() {
    this.baseURL = 'https://api.github.com';
    this.owner = 'discourse';
    this.repo = 'discourse';
  }

  /**
   * Fetch commits between two commit hashes
   * @param {string} startCommit - Starting commit hash
   * @param {string} endCommit - Ending commit hash (defaults to HEAD)
   * @returns {Promise<Array>} Array of commit objects
   */
  async getCommitsBetween(startCommit, endCommit = 'HEAD') {
    try {
      // First, get the commit comparison to find commits between the range
      const compareUrl = `${this.baseURL}/repos/${this.owner}/${this.repo}/compare/${startCommit}...${endCommit}`;

      const response = await fetch(compareUrl, {
        headers: {
          Accept: 'application/vnd.github.v3+json',
          'User-Agent': 'Discourse-Changelog-Viewer',
        },
      });

      if (!response.ok) {
        throw new Error(
          `GitHub API error: ${response.status} ${response.statusText}`
        );
      }

      const data = await response.json();

      // Return the commits array from the comparison
      return data.commits || [];
    } catch (error) {
      console.error('Error fetching commits:', error);
      throw error;
    }
  }

  /**
   * Get a single commit by hash
   * @param {string} commitHash - The commit hash
   * @returns {Promise<Object>} Commit object
   */
  async getCommit(commitHash) {
    try {
      const url = `${this.baseURL}/repos/${this.owner}/${this.repo}/commits/${commitHash}`;

      const response = await fetch(url, {
        headers: {
          Accept: 'application/vnd.github.v3+json',
          'User-Agent': 'Discourse-Changelog-Viewer',
        },
      });

      if (!response.ok) {
        throw new Error(
          `GitHub API error: ${response.status} ${response.statusText}`
        );
      }

      return await response.json();
    } catch (error) {
      console.error('Error fetching commit:', error);
      throw error;
    }
  }

  /**
   * Format commit data for display
   * @param {Object} commit - Raw commit object from GitHub API
   * @returns {Object} Formatted commit object
   */
  formatCommit(commit) {
    const date = new Date(commit.commit.author.date);
    return {
      sha: commit.sha,
      shortSha: commit.sha.substring(0, 7),
      message: commit.commit.message,
      author: {
        name: commit.commit.author.name,
        email: commit.commit.author.email,
        avatar: commit.author?.avatar_url || null,
        username: commit.author?.login || null,
      },
      date: date,
      formattedDate: date.toLocaleDateString(),
      formattedTime: date.toLocaleTimeString(),
      url: commit.html_url,
      stats: commit.stats || null,
    };
  }
}
