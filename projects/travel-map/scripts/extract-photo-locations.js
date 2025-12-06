#!/usr/bin/env node
/**
 * This script extracts GPS coordinates from images in the travel-photos folder
 * and generates a JSON file with the photo locations for the map component.
 */

const fs = require('fs');
const path = require('path');
const exifr = require('exifr');

const TRAVEL_PHOTOS_DIR = path.join(__dirname, '../photos');
const METADATA_FILE = path.join(TRAVEL_PHOTOS_DIR, 'metadata.json');
const OUTPUT_FILE = path.join(__dirname, '../../../src/data/photo-locations.json');

// Supported image extensions
const IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png', '.heic', '.heif'];

/**
 * Recursively find all image files in a directory
 * @param {string} dir - Directory to search
 * @param {string} baseDir - Base directory for calculating relative paths
 * @returns {string[]} Array of relative file paths
 */
function findImageFiles(dir, baseDir = dir) {
  let imageFiles = [];

  const items = fs.readdirSync(dir, { withFileTypes: true });

  for (const item of items) {
    const fullPath = path.join(dir, item.name);

    // Skip metadata.json file
    if (item.name === 'metadata.json') {
      continue;
    }

    if (item.isDirectory()) {
      // Recursively search subdirectories
      imageFiles = imageFiles.concat(findImageFiles(fullPath, baseDir));
    } else if (item.isFile()) {
      const ext = path.extname(item.name).toLowerCase();
      if (IMAGE_EXTENSIONS.includes(ext)) {
        // Store relative path from base directory
        const relativePath = path.relative(baseDir, fullPath);
        imageFiles.push(relativePath);
      }
    }
  }

  return imageFiles;
}

async function extractPhotoLocations() {
  console.log('Extracting GPS data from travel photos...');

  // Check if travel photos directory exists
  if (!fs.existsSync(TRAVEL_PHOTOS_DIR)) {
    console.log('Travel photos directory does not exist. Creating it...');
    fs.mkdirSync(TRAVEL_PHOTOS_DIR, { recursive: true });

    // Create empty locations file
    const outputDir = path.dirname(OUTPUT_FILE);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify([], null, 2));
    console.log('Created empty photo locations file.');
    return;
  }

  // Get all image files recursively
  const files = findImageFiles(TRAVEL_PHOTOS_DIR);

  if (files.length === 0) {
    console.log('No images found in travel-photos directory.');

    // Create empty locations file
    const outputDir = path.dirname(OUTPUT_FILE);
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }
    fs.writeFileSync(OUTPUT_FILE, JSON.stringify([], null, 2));
    return;
  }

  console.log(`Found ${files.length} image(s). Extracting GPS data...`);

  // Load metadata if it exists
  let metadata = {};
  if (fs.existsSync(METADATA_FILE)) {
    try {
      metadata = JSON.parse(fs.readFileSync(METADATA_FILE, 'utf8'));
      console.log(`Loaded metadata for ${Object.keys(metadata).length} photo(s)`);
    } catch (error) {
      console.warn(`Warning: Could not parse metadata.json - ${error.message}`);
    }
  }

  const locations = [];

  for (const file of files) {
    const filePath = path.join(TRAVEL_PHOTOS_DIR, file);
    // Normalize path separators for cross-platform compatibility
    const normalizedPath = file.replace(/\\/g, '/');

    try {
      // Extract GPS data from EXIF
      const exifData = await exifr.gps(filePath);

      // Check if metadata has manual GPS coordinates
      const metadataEntry = metadata[normalizedPath];
      const hasManualGPS = metadataEntry &&
                          typeof metadataEntry.latitude === 'number' &&
                          typeof metadataEntry.longitude === 'number';

      let latitude = null;
      let longitude = null;
      let source = null;

      if (exifData && exifData.latitude && exifData.longitude) {
        latitude = exifData.latitude;
        longitude = exifData.longitude;
        source = 'EXIF';
      } else if (hasManualGPS) {
        latitude = metadataEntry.latitude;
        longitude = metadataEntry.longitude;
        source = 'manual';
      }

      if (latitude !== null && longitude !== null) {
        const location = {
          filename: path.basename(file),
          path: `/travel-photos/${normalizedPath}`,
          latitude: latitude,
          longitude: longitude,
        };

        // Add metadata if available (using normalized path)
        if (metadataEntry) {
          location.name = metadataEntry.name || null;
          location.description = metadataEntry.description || null;
        }

        locations.push(location);
        console.log(`✓ ${normalizedPath}: ${latitude.toFixed(4)}, ${longitude.toFixed(4)} (${source})`);
      } else {
        console.log(`⚠ ${normalizedPath}: No GPS data found`);
      }
    } catch (error) {
      console.error(`✗ ${normalizedPath}: Error reading EXIF data - ${error.message}`);
    }
  }

  // Create output directory if it doesn't exist
  const outputDir = path.dirname(OUTPUT_FILE);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Write locations to JSON file
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(locations, null, 2));

  console.log(`\nExtracted GPS data from ${locations.length} of ${files.length} images.`);
  console.log(`Photo locations saved to: ${OUTPUT_FILE}`);
}

extractPhotoLocations().catch(error => {
  console.error('Error extracting photo locations:', error);
  process.exit(1);
});
