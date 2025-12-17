/**
 * Utility functions for the ZipShare MCP Server
 */

/**
 * Format bytes to human readable string
 */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 Bytes';
  
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(2))} ${sizes[i]}`;
}

/**
 * Format seconds to human readable duration
 */
export function formatDuration(seconds: number): string {
  if (seconds < 60) {
    return `${seconds} seconds`;
  }
  
  if (seconds < 3600) {
    const minutes = Math.floor(seconds / 60);
    return `${minutes} minute${minutes !== 1 ? 's' : ''}`;
  }
  
  if (seconds < 86400) {
    const hours = Math.floor(seconds / 3600);
    return `${hours} hour${hours !== 1 ? 's' : ''}`;
  }
  
  const days = Math.floor(seconds / 86400);
  return `${days} day${days !== 1 ? 's' : ''}`;
}

/**
 * Extract share token from URL or return as-is
 */
export function extractShareToken(input: string): string {
  // Handle full URLs like https://zipshare.io/s/abc123
  const match = input.match(/\/s\/([a-zA-Z0-9_-]+)/);
  if (match) {
    return match[1];
  }
  
  // Return as-is if it looks like a token
  return input;
}

/**
 * Validate file path is safe
 */
export function isPathSafe(filePath: string): boolean {
  // Prevent path traversal
  const normalized = filePath.replace(/\\/g, '/');
  
  if (normalized.includes('..')) {
    return false;
  }
  
  // Must be absolute path
  if (!filePath.startsWith('/') && !filePath.match(/^[A-Za-z]:\\/)) {
    return false;
  }
  
  return true;
}
