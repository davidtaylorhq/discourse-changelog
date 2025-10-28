import { pageTitle } from 'ember-page-title';
import CommitViewer from '../components/commit-viewer';

<template>
  {{pageTitle "Discourse Commit Viewer"}}

  <CommitViewer />

  {{outlet}}
</template>
