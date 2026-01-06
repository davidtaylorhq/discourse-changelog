import { pageTitle } from "ember-page-title";
import CommitViewer from "../components/changelog/commit-viewer";
import metaDescription from "../helpers/meta-description";

<template>
  {{pageTitle "Changelog"}}
  {{metaDescription "Custom changelog viewer"}}

  <CommitViewer
    @start={{@controller.start}}
    @end={{@controller.end}}
    @onUpdateRange={{@controller.updateRange}}
  />
</template>
