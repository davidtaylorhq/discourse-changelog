import CommitViewer from "../components/commit-viewer";
import { pageTitle } from 'ember-page-title';

<template>
{{pageTitle "Changelog"}}

<CommitViewer
  @start={{@controller.start}}
  @end={{@controller.end}}
  @onUpdateStart={{@controller.updateStart}}
  @onUpdateEnd={{@controller.updateEnd}}
/>
</template>