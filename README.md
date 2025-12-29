# Discourse Changelog

A web application for browsing Discourse release history, changelogs, and version information. Built with Ember.js and deployed to GitHub Pages.

## Prerequisites

You will need the following things properly installed on your computer.

- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/)
- [pnpm](https://pnpm.io/)
- [Google Chrome](https://google.com/chrome/)

## Installation

- `git clone <repository-url>` this repository
- `cd discourse-changelog`
- `pnpm install`

## Running / Development

- `pnpm start` - Start the development server
- Visit your app at [http://localhost:5173](http://localhost:5173)

### Generating Data Files

The application requires data files to be generated from the Discourse repository:

- `pnpm build:data` - Generate commits.json and new-features.json

This will:

1. Clone the Discourse repository to `tmp/discourse-repo`
2. Extract commit information and generate `data/commits.json`
3. Fetch new features from meta.discourse.org to `data/new-features.json`

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

This application automatically deploys to GitHub Pages (at discourse-changelog.dtaylor.uk) when changes are pushed to the `main` branch. The deployment workflow generates the data files and builds the site.

## Further Reading / Useful Links

- [ember.js](https://emberjs.com/)
- [Vite](https://vite.dev)
- Development Browser Extensions
  - [ember inspector for chrome](https://chrome.google.com/webstore/detail/ember-inspector/bmdblncegkenkacieihfhpjfppoconhi)
  - [ember inspector for firefox](https://addons.mozilla.org/en-US/firefox/addon/ember-inspector/)
