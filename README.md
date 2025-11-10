# trmccormick.com

Personal website built with Docusaurus, deployed to S3 + CloudFront.

## Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm start

# Build for production
npm run build

# Preview production build
npm run serve
```

## Structure

```
.
├── blog/                  # Blog posts
├── src/
│   ├── components/       # React components
│   ├── css/              # Styles
│   └── pages/            # Static pages
├── static/               # Static assets
├── pagespeed-monitoring/ # AWS Lambda for monitoring
├── scripts/              # Utility scripts
├── docusaurus.config.js  # Configuration
├── package.json          # Dependencies
└── buildspec.yml         # AWS CodeBuild config
```

## Writing a Blog Post

Create a new directory in `blog/`:

```bash
mkdir -p blog/2025-12-01-my-post
```

Create `blog/2025-12-01-my-post/index.md`:

```md
---
title: "My Post Title"
date: 2025-12-01
authors: [trevor]
tags: [tag1, tag2]
image: ./featured.jpg
---

Content here...

<!-- truncate -->

More content after the break...
```

## Deployment

Push to GitHub - CodeBuild will automatically:
1. Install dependencies (`npm ci`)
2. Build the site (`npm run build`)
3. Deploy to S3
4. Invalidate CloudFront cache

## Local Development

```bash
npm start
```

Visit http://localhost:3000

## Tech Stack

- **Docusaurus** - Static site generator
- **React** - UI framework
- **Mermaid** - Diagrams
- **AWS S3** - Hosting
- **AWS CloudFront** - CDN
- **AWS CodeBuild** - CI/CD

## Notes

Your original blog posts are saved on your Desktop in the `trmccormick-saved-posts` folder.
