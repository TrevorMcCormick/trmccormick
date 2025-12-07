module.exports = function () {
  return {
    name: 'non-blocking-css-plugin',

    postBuild({outDir}) {
      const fs = require('fs');
      const path = require('path');

      // Recursively find all HTML files
      function findHtmlFiles(dir) {
        const files = [];
        const items = fs.readdirSync(dir);

        items.forEach((item) => {
          const fullPath = path.join(dir, item);
          const stat = fs.statSync(fullPath);

          if (stat.isDirectory()) {
            files.push(...findHtmlFiles(fullPath));
          } else if (item.endsWith('.html')) {
            files.push(fullPath);
          }
        });

        return files;
      }

      const htmlFiles = findHtmlFiles(outDir);

      // loadCSS polyfill for better browser support
      const loadCSSPolyfill = `<script>!function(e){"use strict";var t=function(t,n,r,o){var i,a=e.document,d=a.createElement("link");if(n)i=n;else{var s=(a.body||a.getElementsByTagName("head")[0]).childNodes;i=s[s.length-1]}var l=a.styleSheets;if(o)for(var f in o)o.hasOwnProperty(f)&&d.setAttribute(f,o[f]);d.rel="stylesheet",d.href=t,d.media="only x",function e(t){if(a.body)return t();setTimeout(function(){e(t)})}(function(){i.parentNode.insertBefore(d,n?i:i.nextSibling)});var u=function(e){for(var t=d.href,n=l.length;n--;)if(l[n].href===t)return e();setTimeout(function(){u(e)})};return d.addEventListener&&d.addEventListener("load",function(){this.media=r||"all"}),d.onloadcssdefined=u,u(function(){d.media!==r&&(d.media=r||"all")}),d};"undefined"!=typeof exports?exports.loadCSS=t:e.loadCSS=t}("undefined"!=typeof global?global:this);</script>`;

      htmlFiles.forEach((file) => {
        let html = fs.readFileSync(file, 'utf8');

        // Replace stylesheet links with preload + onload pattern
        html = html.replace(
          /<link rel="stylesheet" href="([^"]+\.css)">/g,
          '<link rel="preload" href="$1" as="style" onload="this.onload=null;this.rel=\'stylesheet\'"><noscript><link rel="stylesheet" href="$1"></noscript>'
        );

        // Inject loadCSS polyfill before closing head tag for better browser support
        html = html.replace('</head>', `${loadCSSPolyfill}</head>`);

        // Add width/height to avatar images to prevent CLS
        html = html.replace(
          /<img([^>]*class="[^"]*avatar__photo[^"]*"[^>]*)>/g,
          (match, attrs) => {
            if (!attrs.includes('width=') && !attrs.includes('height=')) {
              return `<img${attrs} width="48" height="48">`;
            }
            return match;
          }
        );

        // Add width/height to navbar logo images
        html = html.replace(
          /<img([^>]*class="[^"]*themedComponent[^"]*"[^>]*)>/g,
          (match, attrs) => {
            if (!attrs.includes('width=') && !attrs.includes('height=')) {
              return `<img${attrs} width="32" height="32">`;
            }
            return match;
          }
        );

        // Add inline style to body to prevent CLS from useLockBodyScroll hook
        // This must be inline because our CSS loads async
        html = html.replace(
          /<body([^>]*)>/,
          (match, attrs) => {
            if (attrs.includes('style=')) {
              // Append to existing style
              return match.replace(/style="([^"]*)"/, 'style="$1 overflow: visible;"');
            }
            return `<body${attrs} style="overflow: visible;">`;
          }
        );

        fs.writeFileSync(file, html, 'utf8');
      });
    },
  };
};
