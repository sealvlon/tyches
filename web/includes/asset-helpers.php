<?php
/**
 * Asset Helper Functions
 * Provides cache-busting using file modification time instead of time()
 */

/**
 * Get versioned asset URL using file modification time for cache-busting
 * @param string $path Path to the asset file (relative to web root)
 * @return string The path with version query string
 */
function asset_version(string $path): string {
    $fullPath = __DIR__ . '/../' . ltrim($path, '/');
    
    if (file_exists($fullPath)) {
        $mtime = filemtime($fullPath);
        return $path . '?v=' . $mtime;
    }
    
    // Fallback if file doesn't exist
    return $path;
}

/**
 * Output a CSS link tag with proper versioning
 * @param string $path Path to CSS file
 * @param string $media Media attribute (default: all)
 */
function css_link(string $path, string $media = 'all'): void {
    echo '<link rel="stylesheet" href="' . asset_version($path) . '" media="' . $media . '">';
}

/**
 * Output a script tag with proper versioning
 * @param string $path Path to JS file
 * @param bool $defer Whether to defer loading
 * @param bool $async Whether to load async
 */
function js_script(string $path, bool $defer = false, bool $async = false): void {
    $attrs = '';
    if ($defer) $attrs .= ' defer';
    if ($async) $attrs .= ' async';
    echo '<script src="' . asset_version($path) . '"' . $attrs . '></script>';
}

/**
 * Output preload link for critical resources
 * @param string $path Path to resource
 * @param string $as Resource type (style, script, font, image)
 * @param string|null $type MIME type (optional)
 * @param bool $crossorigin Whether to add crossorigin attribute
 */
function preload_resource(string $path, string $as, ?string $type = null, bool $crossorigin = false): void {
    $attrs = 'rel="preload" href="' . asset_version($path) . '" as="' . $as . '"';
    if ($type) $attrs .= ' type="' . $type . '"';
    if ($crossorigin) $attrs .= ' crossorigin';
    echo '<link ' . $attrs . '>';
}

