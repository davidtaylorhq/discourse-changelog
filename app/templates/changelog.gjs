
import CommitViewer from "../components/commit-viewer";
import { pageTitle } from 'ember-page-title';

<template>
{{pageTitle "Changelog"}}

<CommitViewer
  @start={{this.start}}
  @end={{this.end}}
  @onUpdateStart={{this.updateStart}}
  @onUpdateEnd={{this.updateEnd}}
/>
</template>


