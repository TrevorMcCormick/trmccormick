// @ts-check
// Note: type annotations allow type checking and IDEs autocompletion

const {themes} = require('prism-react-renderer');
const lightTheme = themes.github;
const darkTheme = themes.dracula;

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'trmccormick',
  tagline: 'Product | Data | Basketball',
  favicon: 'img/favicon.ico',

  url: 'https://trmccormick.com',
  baseUrl: '/',

  organizationName: 'TrevorMcCormick',
  projectName: 'trmccormick',

  onBrokenLinks: 'throw',

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: false,
        blog: {
          showReadingTime: true,
          routeBasePath: '/',
          blogTitle: 'Blog',
          blogDescription: 'Trevor McCormick\'s blog - Product, Data, and AWS',
          postsPerPage: 10,
          blogSidebarTitle: 'Recent posts',
          blogSidebarCount: 10,
          feedOptions: {
            type: 'all',
            copyright: `Copyright © ${new Date().getFullYear()} Trevor McCormick.`,
          },
        },
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      }),
    ],
  ],

  headTags: [
    {
      tagName: 'link',
      attributes: {
        rel: 'preconnect',
        href: 'https://fonts.googleapis.com',
      },
    },
    {
      tagName: 'link',
      attributes: {
        rel: 'dns-prefetch',
        href: 'https://cdnjs.cloudflare.com',
      },
    },
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      image: 'img/social-card.jpg',
      navbar: {
        title: 'trmccormick',
        logo: {
          alt: 'Trevor McCormick',
          src: 'https://github.com/trevormccormick.png',
          style: {borderRadius: '50%'},
        },
        items: [
          {to: '/about', label: 'About', position: 'left'},
          {to: '/', label: 'Blog', position: 'left', activeBaseRegex: '^/$|^/page/|^/\\d{4}/|^/tags/|^/archive'},
          {
            href: 'https://github.com/trevormccormick',
            position: 'right',
            className: 'header-github-link',
            'aria-label': 'GitHub repository',
          },
          {
            href: 'https://linkedin.com/in/trevormccormick',
            position: 'right',
            className: 'header-linkedin-link',
            'aria-label': 'LinkedIn profile',
          },
        ],
      },
      footer: {
        style: 'dark',
        links: [
          {
            title: 'Content',
            items: [
              {
                label: 'Blog',
                to: '/',
              },
              {
                label: 'About',
                to: '/about',
              },
            ],
          },
          {
            title: 'Social',
            items: [
              {
                label: 'GitHub',
                href: 'https://github.com/trevormccormick',
              },
              {
                label: 'LinkedIn',
                href: 'https://linkedin.com/in/trevormccormick',
              },
              {
                label: 'Instagram',
                href: 'https://instagram.com/tmccormick92',
              },
            ],
          },
        ],
        copyright: `Copyright © ${new Date().getFullYear()} Trevor McCormick. Built with Docusaurus.`,
      },
      prism: {
        theme: lightTheme,
        darkTheme: darkTheme,
      },
      colorMode: {
        defaultMode: 'light',
        disableSwitch: false,
        respectPrefersColorScheme: true,
      },
    }),

  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },
  themes: ['@docusaurus/theme-mermaid'],

  plugins: [
    './src/plugins/critical-css-plugin.js',
  ],
};

module.exports = config;
