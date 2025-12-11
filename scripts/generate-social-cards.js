const fs = require('fs');
const path = require('path');
const { ImageResponse } = require('@vercel/og');

const BLOG_DIR = path.join(__dirname, '../blog');
const OUTPUT_DIR = path.join(__dirname, '../static/img/social');

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Find all blog post directories
function findBlogPosts() {
  const posts = [];
  const items = fs.readdirSync(BLOG_DIR);

  for (const item of items) {
    const fullPath = path.join(BLOG_DIR, item);
    const stat = fs.statSync(fullPath);

    if (stat.isDirectory()) {
      const indexPath = path.join(fullPath, 'index.md');
      if (fs.existsSync(indexPath)) {
        const content = fs.readFileSync(indexPath, 'utf8');
        const titleMatch = content.match(/title:\s*["']?([^"'\n]+)["']?/);
        if (titleMatch) {
          posts.push({
            slug: item,
            title: titleMatch[1].trim(),
            path: fullPath
          });
        }
      }
    }
  }

  return posts;
}

// Generate social card image
async function generateCard(post) {
  const outputPath = path.join(OUTPUT_DIR, `${post.slug}.png`);

  // Skip if already exists
  if (fs.existsSync(outputPath)) {
    console.log(`  Skipping ${post.slug} (already exists)`);
    return;
  }

  const html = {
    type: 'div',
    props: {
      style: {
        height: '100%',
        width: '100%',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-start',
        justifyContent: 'space-between',
        backgroundColor: '#0369a1',
        padding: '60px 80px',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      },
      children: [
        {
          type: 'div',
          props: {
            style: {
              fontSize: 32,
              color: 'rgba(255,255,255,0.8)',
              fontWeight: 500,
            },
            children: 'trmccormick.com',
          },
        },
        {
          type: 'div',
          props: {
            style: {
              display: 'flex',
              flexDirection: 'column',
              gap: '20px',
            },
            children: [
              {
                type: 'div',
                props: {
                  style: {
                    color: '#fff',
                    fontSize: 56,
                    fontWeight: 700,
                    lineHeight: 1.2,
                    maxWidth: '1000px',
                  },
                  children: post.title,
                },
              },
            ],
          },
        },
      ],
    },
  };

  const response = new ImageResponse(html, {
    width: 1200,
    height: 630,
  });

  const buffer = Buffer.from(await response.arrayBuffer());
  fs.writeFileSync(outputPath, buffer);
  console.log(`  Generated ${post.slug}.png`);
}

async function main() {
  console.log('Generating social cards...');
  const posts = findBlogPosts();
  console.log(`Found ${posts.length} blog posts`);

  for (const post of posts) {
    await generateCard(post);
  }

  console.log('Done!');
}

main().catch(console.error);
