---
title: "How This Website Works - Part 1"
date: 2025-11-13
authors: [trevor]
tags: [aws, infrastructure, cloudfront, s3, dns]
image: ./simple.webp
---

This website is basically a set of static files.

<!-- truncate -->

### A Quick Diagram

```mermaid
graph LR
    Start[Bob types trmccormick.com] --> DNS[DNS Resolution]
    DNS --> TCP[TCP/TLS Handshake]
    TCP --> Content[Content Delivery - Part 2]

    style Start fill:#e2e8f0,stroke:#64748b
    style DNS fill:#0ea5e9,stroke:#0284c7,stroke-width:3px,color:#fff
    style TCP fill:#0ea5e9,stroke:#0284c7,stroke-width:3px,color:#fff
    style Content fill:#64748b,stroke:#94a3b8,stroke-width:2px,stroke-dasharray:5,color:#fff
```

### DNS Resolution

> Bob types `trmccormick.com` into his browser.

Bob's browser doesn't know what `trmccormick.com` is; it needs to map that website to an IP address.

First, it checks its local DNS cache. That's the in-memory mapping table Bob's browser holds on to so it doesn't have to make redundant DNS queries for websites he has visited before. It only holds on to websites he has visited in his current browsing session. 

If it is not in the local DNS cache, it asks the operating system's DNS resolver. That's is a system-wide cache that all applications contribute to and can look at.

If it is not in there either, the next check could be the router cache. So if anyone in Bob's house (using his router) has looked up `trmccormick.com` recently, the browser can grab my website's IP address. And by recently, I basically mean within the TTL I set up for my site (which is relatively high because I'm not making groundbreaking updates to my site every few minutes).

But let's say, sadly, no one in Bob's house has visited my website recently. The last part of the DNS resolution is at the ISP level. The ISP DNS resolver queries one of the thirteen root nameserver clusters and asks "what is the IP address for `trmccormick.com`?" The root nameserver says "no idea but I do know the top-level domain nameservers for `.com` domains that you can ask". 

So the ISP resolver then queries that TLD (top-level domain) nameserver with the same question. Another riddle -- "I don't know either... but I do know who is supposed to know." And it spits out some Route53 nameservers. The ISP resolver can then query those, and Route53 thinks about it for a moment-- it finds my website's CloudFront distribution (`d3h14m6i672ywk.cloudfront.net`), but instead of giving that to the ISP resolver, Route53 will resolve that on its own so it can give the ISP back the IP address directly. 

How does Route53 figure out which IP address to give to Bob? When the ISP resolver queries Route53, it includes Bob's subnet information. So the query says "I'm asking on behalf of a client in the 68.42.x.x range (Comcast Detroit -- the ISP Bob uses)." Route53 passes that subnet info along when it queries CloudFront's DNS, and CloudFront returns an IP from the nearest regional pool. 

The IP address then travels back down the chain: CloudFront ➡️ Route53 → ISP resolver → Bob's router ➡️ Bob's browser. Total time for all of this: maybe 50-100ms if nothing was cached. If Bob's ISP had recently resolved my website for another customer, it could be under 10ms. 

### The TCP/TLS Handshake

Now Bob has an IP address. Time to actually connect. This is TCP (Transmission Control Protocol) handshake. Think of it like making a phone call: 

- Bob's browser sends a packet to this IP address (Bob's browser dials the phone number)
- CloudFront edge receives the packet and sends one back to Bob's browser (phone rings, CloudFront picks up and says "hello")
- Bob's browser receives the packet and sends another back to CloudFront (Bob's browser says "hello, it's Bob's browser")

There hasn't really been a conversation yet; more like an agreement to begin a conversation. And before they truly begin talking, they want to ensure they're on a safe connection (encrypted). This is the TLS (Transport Layer Security) handshake. Bob's browser sends another packet (called a ClientHello) to CloudFront "Here are the encryption methods I support." CloudFront responds with a ServerHello and gives Bob's browser the TLS certificate (the one I setup on my website through AWS Certificate Manager for trmccormick.com). 

Bob's browser does three things to verify this certificate:
- Does the domain match what Bob typed? (trmccormick.com)
- Has the certificate expired?
- Can the signature chain be trusted?

The signature chain is like a chain letter of recommendation all in the same envelope. Bob's browser comes pre-installed with a list of trusted root Certificate Authorities. When CloudFront sends the TLS certificate, it basically is sent with an envelope with:
- a signed letter from Amazon Trust Services that says "this is trmccormick.com"
- a signed letter from "some company ABC" that signed Amazon's certificate that says "you can trust Amazon Trust Services"
- eventually, a signed letter from one of Bob's browser's root Certificate Authorities that says "you can trust 'some company ABC'"

If any of that fails, Bob's browser would show Bob a "Your connection is not private" page (which Bob could bypass if he really wanted to).

So after Bob's browser trusts the certificate, Bob's browser and CloudFront's edge server establish encrypted communication.  I have no idea how that works but it is some advanced math. 


### Actually Getting the Content
But Bob still haven't actually downloaded anything yet. All of this stuff -- DNS lookups, TCP handshakes, TLS negotiation -- was just to establish a secure connection. Now Bob's browser can finally ask: "Give me the homepage."  
