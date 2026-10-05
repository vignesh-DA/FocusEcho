/**
 * @fileoverview Hostname utilities. Hostname-only policy enforced here.
 * This module MUST NOT read, store, or transmit URL paths, query strings,
 * fragments, page titles, or page content. Every call site has a comment
 * confirming this constraint.
 */

/**
 * Extract and normalise a hostname from a URL string or a raw hostname.
 * Returns empty string on failure — never throws.
 *
 * Examples:
 *   normalizeHost('https://www.twitter.com/home') → 'twitter.com'
 *   normalizeHost('twitter.com')                  → 'twitter.com'
 *   normalizeHost('')                              → ''
 *
 * @param {string} value - A full URL or a bare hostname.
 * @returns {string} Lowercase hostname without www. prefix.
 */
export function normalizeHost(value) {
  if (!value) return '';
  try {
    // If it looks like a URL (has a scheme), parse it. Otherwise treat as host.
    const str = value.includes('://') ? value : `https://${value}`;
    // Only the hostname is extracted. path/query/hash are deliberately ignored.
    const host = new URL(str).hostname;
    return host.toLowerCase().replace(/^www\./, '');
  } catch (_) {
    return '';
  }
}

/**
 * Test whether a URL or hostname is on the user's distraction list.
 *
 * @param {string} urlOrHost - A full URL or bare hostname.
 * @param {string[]} distractionList - Array of hostnames (already normalised).
 * @returns {boolean}
 */
export function isDistracting(urlOrHost, distractionList) {
  if (!urlOrHost || !distractionList?.length) return false;
  const host = normalizeHost(urlOrHost);
  if (!host) return false;
  return distractionList.some((site) => {
    const target = normalizeHost(site);
    return target && (host === target || host.endsWith(`.${target}`));
  });
}

/**
 * Returns true if the URL is a navigable web page we can inspect.
 * Filters out chrome://, chrome-extension://, about:, data:, etc.
 *
 * @param {string} url
 * @returns {boolean}
 */
export function isWebUrl(url) {
  return typeof url === 'string' && /^https?:\/\//i.test(url);
}
