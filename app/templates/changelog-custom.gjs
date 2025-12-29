import { pageTitle } from "ember-page-title";
import CommitViewer from "../components/commit-viewer";
import metaDescription from "../helpers/meta-description";

<template>
  {{pageTitle "Changelog"}}
  {{metaDescription "Custom changelog viewer"}}

  <CommitViewer
    @start={{@controller.start}}
    @end={{@controller.end}}
    @onUpdateStart={{@controller.updateStart}}
    @onUpdateEnd={{@controller.updateEnd}}
  />
</template>
