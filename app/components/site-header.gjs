import Component from '@glimmer/component';
import './site-header.css';

export default class SiteHeader extends Component {

  <template>
    <header class="site-header">
      <div class="header-content">
        <div class="header-left">
          <a href="https://discourse.org" class="logo-link">
            <img src="/logo-small-light.png" alt="Discourse" class="logo logo-light" />
            <img src="/logo-small-dark.png" alt="Discourse" class="logo logo-dark" />
          </a>

          <h1 class="site-title">
            <a href="/" class="title-link">Discourse Releases</a>
          </h1>
        </div>

        <nav class="external-links">
          <a href="https://discourse.org" class="external-link" target="_blank" rel="noopener noreferrer">Website ↗</a>
          <a href="https://meta.discourse.org" class="external-link" target="_blank" rel="noopener noreferrer">Meta ↗</a>
          <a href="https://github.com/discourse/discourse" class="external-link" target="_blank" rel="noopener noreferrer">GitHub ↗</a>
        </nav>
      </div>
    </header>
  </template>
}
