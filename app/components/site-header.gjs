import "./site-header.css";
import Logo from "./logo.gjs";

export default <template>
  <header class="site-header">
    <div class="header-content">
      <div class="header-left">
        <h1 class="site-title">
          <a href="/" class="title-link">
            <Logo class="logo" />
            <span>Discourse Releases</span>
          </a>
        </h1>
      </div>

      <nav class="external-links">
        <a
          href="https://discourse.org"
          class="external-link"
          target="_blank"
          rel="noopener noreferrer"
        >Website ↗</a>
        <a
          href="https://meta.discourse.org"
          class="external-link"
          target="_blank"
          rel="noopener noreferrer"
        >Meta ↗</a>
        <a
          href="https://github.com/discourse/discourse"
          class="external-link"
          target="_blank"
          rel="noopener noreferrer"
        >GitHub ↗</a>
      </nav>
    </div>
  </header>
</template>
