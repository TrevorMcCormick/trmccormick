#!/usr/bin/env node

/**
 * Fetches PageSpeed metrics from API and saves to static file
 * Run this script before building the site to pre-fetch metrics data
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const API_URL = 'https://k81f3vqwt5.execute-api.us-east-1.amazonaws.com/prod/metrics';
const OUTPUT_DIR = path.join(__dirname, '..', 'static', 'data');
const OUTPUT_FILE = path.join(OUTPUT_DIR, 'pagespeed-metrics.json');

function fetchMetrics() {
  return new Promise((resolve, reject) => {
    console.log('Fetching PageSpeed metrics from API...');

    https.get(API_URL, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        if (res.statusCode === 200) {
          try {
            const jsonData = JSON.parse(data);
            resolve(jsonData);
          } catch (error) {
            reject(new Error(`Failed to parse JSON: ${error.message}`));
          }
        } else {
          reject(new Error(`API request failed with status ${res.statusCode}`));
        }
      });
    }).on('error', (error) => {
      reject(new Error(`Network error: ${error.message}`));
    });
  });
}

async function main() {
  try {
    const metrics = await fetchMetrics();

    // Ensure output directory exists
    if (!fs.existsSync(OUTPUT_DIR)) {
      fs.mkdirSync(OUTPUT_DIR, { recursive: true });
      console.log(`Created directory: ${OUTPUT_DIR}`);
    }

    // Write metrics to file
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(metrics, null, 2));
    console.log(`✓ Successfully saved metrics to ${OUTPUT_FILE}`);
    console.log(`  Found ${metrics.metrics?.length || 0} metric entries`);

    process.exit(0);
  } catch (error) {
    console.error('✗ Error fetching PageSpeed metrics:', error.message);

    // Create fallback empty data file so builds don't fail
    if (!fs.existsSync(OUTPUT_DIR)) {
      fs.mkdirSync(OUTPUT_DIR, { recursive: true });
    }

    const fallbackData = {
      metrics: [],
      lastUpdated: new Date().toISOString(),
      error: error.message
    };

    fs.writeFileSync(OUTPUT_FILE, JSON.stringify(fallbackData, null, 2));
    console.log(`Created fallback data file to prevent build failure`);

    // Exit with 0 so build continues even if fetch fails
    process.exit(0);
  }
}

main();
