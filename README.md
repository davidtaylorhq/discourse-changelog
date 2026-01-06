# Discourse Releases

A web application for browsing Discourse release history, changelogs, and version support information. Built with Ember.js and deployed to GitHub Pages.

Live at: [releases.discourse.org](https://releases.discourse.org)

## Installation

- `git clone <repository-url>` this repository
- `cd discourse-releases`
- `pnpm install`

## Running / Development

- `pnpm start` - Start the development server

### Generating Data Files

The application requires data files to be generated from the Discourse repository:

- `pnpm build:data` - Generate commits.json, new-features.json, and security-advisories.json

This will:

1. Clone the Discourse repository to `tmp/discourse-repo`
2. Extract commit information and generate `data/commits.json`
3. Fetch new features from meta.discourse.org to `data/new-features.json`
4. Fetch security advisories from GitHub to `data/security-advisories.json`

**Note**: This process can take several minutes and requires git to be installed.

### Running Tests

- `pnpm test`

### Linting

- `pnpm lint`
- `pnpm lint:fix`

### Building

- `pnpm build` - Build for production (outputs to `dist/`)
- `pnpm build:full` - Generate data files and build for production

### Deploying

This application automatically deploys to GitHub Pages when changes are pushed to the `main` branch. The deployment workflow generates the data files and builds the site.

To keep commit data fresh, deploys are re-run every 15 minutes, and can also be triggered manually by repository owners.
