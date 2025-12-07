module.exports = function () {
  return {
    name: 'image-dimensions-plugin',

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

      htmlFiles.forEach((file) => {
        let html = fs.readFileSync(file, 'utf8');

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

        fs.writeFileSync(file, html, 'utf8');
      });
    },
  };
};
