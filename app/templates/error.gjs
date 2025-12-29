import "./error.css";
import { pageTitle } from "ember-page-title";

<template>
  {{pageTitle "Page Not Found"}}

  <div class="error-container">
    <div class="error-content">
      <h1 class="error-title">404</h1>
      <h2 class="error-subtitle">Page Not Found</h2>
      <p class="error-message">
        The page you're looking for doesn't exist or has been moved.
      </p>
      <a href="/" class="error-link">← Back to Discourse Releases</a>
    </div>
  </div>
</template>
