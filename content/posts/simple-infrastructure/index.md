---
title: "Keep it Simple"
date: 2025-11-13T10:00:00-05:00
draft: false
tags: [AWS, Hugo, Architecture, Infrastructure]
---

This website is basically a set of static files on S3, served through Cloudfront. 

## How This Site Works: The Network Journey

Bob types `trmccormick.com` into his browser.

### DNS Resolution: The Address Lookup

Bob's browser doesn't know what `trmccormick.com` is; it needs to map that website to an IP address.

First, it checks its local DNS cache. That's the in-memory mapping table Bob's browser holds on to so it doesn't have to make redundant DNS queries for websites he has visited before. It only holds on to websites he has visited in his current browsing session. 

If it is not in the local DNS cache, it asks the operating system's DNS resolver. That's is a system-wide cache that all applications contribute to and can look at.

If it is not in there either, the next check could be the router cache. So if anyone in Bob's house (using his router) has looked up `trmccormick.com` recently, the browser can grab my website's IP address. And by recently, I basically mean within the TTL I set up for my site (which is relatively high because I'm not making groundbreaking updates to my site every few minutes).

But let's say, sadly, no one in Bob's house has visited my website recently. The last part of the DNS resolution is at the ISP level. The ISP DNS resolver queries one of the thirteen root nameserver clusters and asks "what is the IP address for `trmccormick.com`?" The root nameserver says "no idea but I do know the top-level domain nameservers for `.com` domains that you can ask". 

So the ISP resolver then queries that TLD (top-level domain) nameserver with the same question. Another riddle -- "I don't know either... but I do know who is supposed to know." And it spits out some Route53 nameservers. The ISP resolver can then query those, and Route53 thinks about it for a moment-- it finds my website's CloudFront distribution (`d3h14m6i672ywk.cloudfront.net`), but instead of giving that to the ISP resolver, Route53 resolves that on its own so it can give the ISP back the IP address directly. And it 

So 

### More About CloudFront

CloudFront operates 450+ edge locations across 90+ cities in 48 countries. When Route53 queries DNS for the distribution domain, CloudFront's DNS doesn't just hand back a single IP address. It uses geolocation and health checks to return the IP address of the nearest, healthiest edge location to the Bob's browser.

This is where Anycast comes in. Multiple edge locations can advertise the same IP address using Border Gateway Protocol (BGP). Internet routers use BGP to find the shortest path to that IP, which naturally routes traffic to the geographically closest edge location. If an edge location goes down, BGP reconverges and traffic routes to the next nearest location.

From your ISP's perspective in, say, Chicago, the DNS query returns an IP address for CloudFront's Chicago edge location (likely in the Digital Realty data center in Franklin Park). Someone in Frankfurt gets an IP for the Frankfurt edge location.

### The TLS Handshake: Establishing Encryption

Now the browser has an IP address. It initiates a TCP connection to that edge location—three-way handshake, SYN, SYN-ACK, ACK. This takes one round trip, maybe 10-30ms depending on geographic distance.

Next comes the TLS handshake. The browser sends a ClientHello specifying supported cipher suites. The edge location responds with a ServerHello and presents the TLS certificate—the ACM certificate for `trmccormick.com`.

ACM (AWS Certificate Manager) stores these certificates, but edge locations cache them locally. The certificate includes the public key. The browser verifies the certificate chain (checking that it's signed by a trusted Certificate Authority) and verifies the domain matches.

Using elliptic curve Diffie-Hellman (ECDHE), both sides establish a shared secret without transmitting it. This takes another round trip. Modern TLS 1.3 reduces this to a single round trip, and with session resumption, subsequent visits skip most of this.

Total time for TCP and TLS: 20-50ms.

### HTTP Request and Edge Cache Lookup

The browser sends an HTTP/2 (or HTTP/3 over QUIC) request: `GET /index.html HTTP/2`. CloudFront edge locations run nginx-based servers optimized for caching. The edge location checks its local cache using the request URL as the cache key.

CloudFront's cache is a multi-tiered LRU (Least Recently Used) system. Hot content stays in memory. Warm content lives on local SSDs. If the content is cached and fresh (based on Cache-Control headers), the edge location returns it immediately. Response time: sub-10ms from cache lookup to response.

If not cached, the edge location becomes a proxy. But it doesn't go directly to the origin (S3) yet. CloudFront uses Regional Edge Caches—larger, intermediate caching layers in AWS regions. There are 13 regional edge caches globally. The edge location in Chicago might query the regional cache in Ohio.

### The Origin Request: S3 via AWS Backbone

If the regional cache doesn't have it either, we're going to the origin: the S3 bucket `trmccormick.com` in `us-east-1` (Northern Virginia).

This request doesn't traverse the public internet. AWS operates a private fiber backbone connecting all regions and edge locations. From the CloudFront edge to S3, traffic flows over this dedicated network. Latency is lower, and bandwidth is higher than public internet routes.

The edge location (or regional cache) makes an HTTP request to S3: `GET /index.html`. S3 is object storage, not a filesystem. Objects are distributed across multiple drives and servers within an Availability Zone for durability. S3 retrieves the object from its distributed storage system, applies any server-side encryption (at rest), and returns it.

Because the S3 bucket is configured for static website hosting, S3 serves the content with appropriate MIME types (`text/html` for HTML, `text/css` for CSS, etc.). The response includes Cache-Control headers we set during deployment: `public, max-age=3600` for HTML.

### The Response Journey Back

CloudFront receives the S3 response, stores it in the regional cache and the edge cache according to the Cache-Control headers, and forwards it to the browser. The browser receives the HTML, parses it, and discovers it needs CSS, JavaScript, and images.

It makes additional requests for those resources. Same process, but faster—because CloudFront cached those fingerprinted assets with year-long Cache-Control headers, they're almost certainly still cached from previous visitors.

The entire process—DNS resolution, TCP connection, TLS handshake, HTTP request, cache lookup, origin retrieval (if needed), and response—completes in 80-150ms for an uncached request. Cached requests drop to 20-50ms.

### What Makes This Fast

Several factors compound:

**Geographic distribution**: Content serves from 450+ locations instead of a single data center. Chicago visitors hit Chicago servers, not Virginia servers 700 miles away.

**Aggressive caching**: Static content doesn't change. Cache it once, serve it thousands of times. CloudFront's cache hit rate for this site exceeds 95%.

**AWS private backbone**: Origin requests avoid public internet congestion and peering issues. Consistent, low-latency connectivity between CloudFront and S3.

**No compute overhead**: No server-side rendering. No database queries. No application logic. Just file retrieval from cache or object storage.

**Protocol optimizations**: HTTP/2 multiplexing, header compression, and server push reduce request overhead. TLS 1.3 and session resumption minimize handshake latency.

**Pre-compressed assets**: Hugo generates Brotli and gzip versions at build time. CloudFront serves pre-compressed files based on Accept-Encoding headers, avoiding runtime compression.

The stack is simple—DNS, CDN, object storage. But the underlying infrastructure is sophisticated. Route53 uses Anycast and health checks. CloudFront operates a massive distributed caching system with regional tiers. S3 distributes objects across multiple drives and servers for durability.

The simplicity is in the architecture. The sophistication is in the implementation.

## The Build Process

This site runs on Hugo, a static site generator written in Go. When I push changes to the repository, AWS CodeBuild executes a build using this `buildspec.yml`:

### Install Phase

```yaml
- wget https://golang.org/dl/go1.23.3.linux-amd64.tar.gz
- tar -xzf go1.23.3.linux-amd64.tar.gz
- mv go /usr/local
```

We install Go 1.23.3 because Hugo requires it for compilation. CodeBuild environments are ephemeral—each build starts fresh—so we install dependencies every time. This adds 30 seconds to the build. Could we use a custom Docker image with Go pre-installed? Yes. But that introduces another artifact to maintain, version, and secure. For a site that builds weekly, the trade-off doesn't justify the overhead.

```yaml
- git clone --branch v0.139.4 --depth 1 https://github.com/gohugoio/hugo.git
- cd hugo
- go install --tags extended
```

We clone Hugo v0.139.4 specifically (shallow clone, no git history) and compile it with the extended tag for SCSS processing and WebP image encoding. Version pinning matters—Hugo moves fast, and new releases occasionally break templates. I learned this when v0.139.0 deprecated functions I was using. Pinning versions prevents surprise failures.

### Build Phase

```yaml
- hugo --minify
```

This command reads Markdown files, applies templates, processes images, bundles assets, and outputs a complete static site in under 3 seconds. The `--minify` flag compresses output files. Compare this to a typical React build with Webpack, which might take 2-3 minutes for a similar-sized site.

### Deployment with Strategic Caching

```yaml
- aws s3 sync --exclude "*" --include "*.html" --cache-control "public, max-age=3600" docs/ s3://trmccormick.com
- aws s3 sync --exclude "*" --include "*.css" --cache-control "public, max-age=31536000, immutable" docs/ s3://trmccormick.com
```

We run multiple S3 sync commands with different cache headers. HTML gets a 1-hour cache because content changes and should propagate reasonably quickly. CSS and JavaScript get a 1-year cache with the `immutable` flag because Hugo fingerprints them—filenames include content hashes like `styles.a3b2c1d4.css`. When content changes, the filename changes, enabling aggressive caching without stale content.

Images get the same year-long cache treatment.

```yaml
- aws s3 sync --delete docs/ s3://trmccormick.com
```

A final sync with `--delete` removes files that no longer exist in the build output.

### CloudFront Invalidation

```yaml
- aws cloudfront create-invalidation --distribution-id E31546NI4VOO5F --paths '/*'
```

We clear the entire CDN cache after deployment. This is somewhat heavy-handed—we could invalidate only changed files—but invalidations are cheap (first 1,000 monthly are free) and builds are infrequent. For high-traffic production applications with frequent deployments, surgical invalidations make more sense. For this use case, clearing everything ensures consistency without meaningful cost.

## The Trade-offs That Matter

### Static vs. Dynamic Rendering

Static site generation means every page is pre-rendered at build time. No server computes anything on request.

**Advantages:**
- Sub-100ms page loads
- Infinite scaling (S3 and CloudFront handle any traffic spike)
- Minimal operational overhead
- Monthly costs measured in single-digit dollars

**Limitations:**
- Dynamic features require client-side JavaScript
- Content changes require full rebuilds
- No server-side personalization

For blogs and documentation, this trade-off is obvious. For data products with real-time dashboards, it's different. But many data platforms could benefit from hybrid approaches—static documentation, pre-rendered views for common queries, cached API responses. We default to dynamic rendering when static would handle 80% of use cases.

### Build-from-Source vs. Pre-built Binaries

Compiling Hugo from source on every build is inefficient. But it provides control. I know exactly which version I'm getting. I can audit the source if needed. I don't depend on binaries hosted elsewhere.

In regulated industries—finance, healthcare, pharmaceuticals—this matters. When security teams ask where a binary originated, pointing to source code and a reproducible build process is valuable.

### Granular Caching Strategies

The multiple S3 sync commands with different cache headers optimize for browser caching and CDN efficiency. A single sync command with one cache policy would work but would be slower for users and slightly more expensive for CloudFront data transfer.

This pattern appears repeatedly in data platforms: conflating "works" with "works well." Basic implementations work. Optimized versions work better. Not dramatically, but measurably. These micro-optimizations compound—50ms here, 200ms there, and dashboards shift from sluggish to responsive.

### The Economics of Simplicity

This entire infrastructure—DNS, CDN, storage, SSL, builds—costs about $5 monthly. CodeBuild runs roughly 20 builds per month, each completing in under 2 minutes. S3 storage costs pennies. CloudFront data transfer is the largest expense and remains negligible.

A typical three-tier web application costs:
- Load balancer: $20/month minimum
- EC2 instances or ECS tasks: $50-200/month
- RDS database: $50-500/month
- Additional services: variable

Total: $150-1,000 monthly before traffic costs. Add operational overhead—patching servers, managing databases, monitoring application health, rotating secrets.

For serving static content that changes occasionally, this cost structure doesn't make sense.

## Implications for Data Platforms

Data products are complex applications with real-time queries, authentication, and interactive dashboards. But consider how much could be static or pre-computed:

- API documentation
- Data dictionaries and schemas
- Common dashboard views
- Historical reports
- Metric rollups and aggregations

In enterprise data products, we often over-engineer. We build dynamic systems for data that changes hourly. We create real-time dashboards for metrics checked daily. We implement complex caching layers when pre-computation would work.

The JAMstack pattern—JavaScript, APIs, and Markup—separates concerns cleanly. Static content lives on CDNs. Dynamic functionality happens through API calls. You get performance and cost benefits of static hosting where appropriate, reserving compute resources for genuinely dynamic work.

### A Concrete Example

I worked on a data platform serving usage metrics to executives. The original architecture queried a data warehouse on every page load, aggregated metrics in real-time, and rendered charts server-side. Response times averaged 2-3 seconds. AWS costs ran $8,000 monthly.

We redesigned it: pre-compute metric rollups hourly, generate static HTML for common views, serve through CloudFront, use JavaScript for interactive filtering. Response times dropped to 200ms. Costs fell to $1,200 monthly.

Same functionality. Better experience. 85% cost reduction.

Most dashboards show the same data to the same people repeatedly. Pre-rendering and caching isn't a limitation—it's an optimization.

## Matching Tools to Problems

Building infrastructure isn't about using the newest technology. It's not about Kubernetes because it's popular, serverless because it's trendy, or microservices because large tech companies use them.

It's about matching tools to problems. Understanding trade-offs. Questioning assumptions.

This website uses proven, unglamorous technology: static files, object storage, a CDN, and a build pipeline. Nothing innovative. Nothing conference-worthy. But it's fast, reliable, cheap, and requires minimal maintenance. Time goes to writing content, not debugging deployment pipelines or troubleshooting database connections.

Data platforms deserve the same scrutiny. Before reaching for complex solutions, ask: what's the simplest approach that could work? Can we pre-compute this? Do we need real-time, or would near-real-time suffice? Are we building for actual requirements or imagined scale?

The best infrastructure operates invisibly. It works quietly and efficiently, letting teams focus on delivering value to users.

Sometimes that means choosing the proven solution. The one that's been working since 2006. The one that scales to millions of requests without drama.

Static files on a CDN. Boring? Perhaps. Effective? Demonstrably.
