#!/usr/bin/env node
/**
 * ZipShare MCP Server
 * 
 * Enables AI agents to transfer files using ZipShare.
 * Compatible with Claude, ChatGPT, and other MCP-enabled AI systems.
 * 
 * @example
 * // In your MCP client configuration:
 * {
 *   "mcpServers": {
 *     "zipshare": {
 *       "command": "npx",
 *       "args": ["@zipshare/mcp-server"],
 *       "env": {
 *         "ZIPSHARE_API_KEY": "your-api-key"
 *       }
 *     }
 *   }
 * }
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ErrorCode,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import { ZipShareClient } from './client.js';
import { formatBytes, formatDuration } from './utils.js';

const API_KEY = process.env.ZIPSHARE_API_KEY;
const API_URL = process.env.ZIPSHARE_API_URL || 'https://api.zipshare.io';

if (!API_KEY) {
  console.error('Error: ZIPSHARE_API_KEY environment variable is required');
  process.exit(1);
}

const client = new ZipShareClient(API_URL, API_KEY);

const server = new Server(
  {
    name: 'zipshare',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

/**
 * List available tools for AI agents
 */
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: 'send_file',
        description: 'Upload a file to ZipShare and get a shareable link. The recipient can download without an account.',
        inputSchema: {
          type: 'object',
          properties: {
            file_path: {
              type: 'string',
              description: 'Absolute path to the file to upload',
            },
            recipient_email: {
              type: 'string',
              description: 'Optional: Email address to notify when file is ready',
            },
            message: {
              type: 'string',
              description: 'Optional: Message to include with the file',
            },
            password: {
              type: 'string',
              description: 'Optional: Password to protect the download link',
            },
            expires_in: {
              type: 'number',
              description: 'Optional: Hours until link expires (default: 168 = 7 days)',
            },
            max_downloads: {
              type: 'number',
              description: 'Optional: Maximum number of downloads allowed',
            },
          },
          required: ['file_path'],
        },
      },
      {
        name: 'send_files',
        description: 'Upload multiple files and get a single shareable link for all of them.',
        inputSchema: {
          type: 'object',
          properties: {
            file_paths: {
              type: 'array',
              items: { type: 'string' },
              description: 'Array of absolute paths to files to upload',
            },
            recipient_email: {
              type: 'string',
              description: 'Optional: Email to notify when files are ready',
            },
            message: {
              type: 'string',
              description: 'Optional: Message to include',
            },
            password: {
              type: 'string',
              description: 'Optional: Password protection',
            },
            expires_in: {
              type: 'number',
              description: 'Optional: Hours until expiration',
            },
          },
          required: ['file_paths'],
        },
      },
      {
        name: 'get_transfer_status',
        description: 'Check the status of a file transfer by its ID or share link.',
        inputSchema: {
          type: 'object',
          properties: {
            transfer_id: {
              type: 'string',
              description: 'The transfer ID or share link URL',
            },
          },
          required: ['transfer_id'],
        },
      },
      {
        name: 'list_transfers',
        description: 'List recent file transfers from your account.',
        inputSchema: {
          type: 'object',
          properties: {
            limit: {
              type: 'number',
              description: 'Number of transfers to return (default: 10, max: 50)',
            },
            status: {
              type: 'string',
              enum: ['pending', 'uploading', 'completed', 'failed', 'expired'],
              description: 'Filter by status',
            },
          },
        },
      },
      {
        name: 'delete_transfer',
        description: 'Delete a transfer and revoke its share link.',
        inputSchema: {
          type: 'object',
          properties: {
            transfer_id: {
              type: 'string',
              description: 'The transfer ID to delete',
            },
          },
          required: ['transfer_id'],
        },
      },
      {
        name: 'get_download_link',
        description: 'Get a direct download link for a transfer (requires the share link password if protected).',
        inputSchema: {
          type: 'object',
          properties: {
            share_token: {
              type: 'string',
              description: 'The share token from the share URL',
            },
            password: {
              type: 'string',
              description: 'Password if the link is protected',
            },
          },
          required: ['share_token'],
        },
      },
    ],
  };
});

/**
 * Handle tool execution requests from AI agents
 */
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'send_file': {
        const { file_path, recipient_email, message, password, expires_in, max_downloads } = args as {
          file_path: string;
          recipient_email?: string;
          message?: string;
          password?: string;
          expires_in?: number;
          max_downloads?: number;
        };

        const result = await client.uploadFile(file_path, {
          recipientEmail: recipient_email,
          message,
          password,
          expiresIn: expires_in,
          maxDownloads: max_downloads,
        });

        return {
          content: [
            {
              type: 'text',
              text: `✅ File uploaded successfully!

**File:** ${result.fileName}
**Size:** ${formatBytes(result.fileSize)}
**Share Link:** ${result.shareUrl}
${password ? '**Password Protected:** Yes' : ''}
**Expires:** ${result.expiresAt}
${recipient_email ? `**Notification sent to:** ${recipient_email}` : ''}

The recipient can download the file at: ${result.shareUrl}`,
            },
          ],
        };
      }

      case 'send_files': {
        const { file_paths, recipient_email, message, password, expires_in } = args as {
          file_paths: string[];
          recipient_email?: string;
          message?: string;
          password?: string;
          expires_in?: number;
        };

        const result = await client.uploadFiles(file_paths, {
          recipientEmail: recipient_email,
          message,
          password,
          expiresIn: expires_in,
        });

        return {
          content: [
            {
              type: 'text',
              text: `✅ ${result.fileCount} files uploaded successfully!

**Total Size:** ${formatBytes(result.totalSize)}
**Share Link:** ${result.shareUrl}
${password ? '**Password Protected:** Yes' : ''}
**Expires:** ${result.expiresAt}

Files included:
${result.files.map((f: { name: string; size: number }) => `- ${f.name} (${formatBytes(f.size)})`).join('\n')}`,
            },
          ],
        };
      }

      case 'get_transfer_status': {
        const { transfer_id } = args as { transfer_id: string };
        const result = await client.getTransferStatus(transfer_id);

        return {
          content: [
            {
              type: 'text',
              text: `**Transfer Status**

**ID:** ${result.id}
**File:** ${result.fileName}
**Size:** ${formatBytes(result.fileSize)}
**Status:** ${result.status}
**Progress:** ${result.progress}%
**Downloads:** ${result.downloadCount}${result.maxDownloads ? `/${result.maxDownloads}` : ''}
**Created:** ${result.createdAt}
**Expires:** ${result.expiresAt}
${result.shareUrl ? `**Share Link:** ${result.shareUrl}` : ''}`,
            },
          ],
        };
      }

      case 'list_transfers': {
        const { limit = 10, status } = args as { limit?: number; status?: string };
        const result = await client.listTransfers({ limit, status });

        if (result.transfers.length === 0) {
          return {
            content: [
              {
                type: 'text',
                text: 'No transfers found.',
              },
            ],
          };
        }

        const transferList = result.transfers
          .map(
            (t: {
              id: string;
              fileName: string;
              fileSize: number;
              status: string;
              createdAt: string;
            }) =>
              `- **${t.fileName}** (${formatBytes(t.fileSize)}) - ${t.status} - ${t.createdAt}`
          )
          .join('\n');

        return {
          content: [
            {
              type: 'text',
              text: `**Recent Transfers** (${result.transfers.length})\n\n${transferList}`,
            },
          ],
        };
      }

      case 'delete_transfer': {
        const { transfer_id } = args as { transfer_id: string };
        await client.deleteTransfer(transfer_id);

        return {
          content: [
            {
              type: 'text',
              text: `✅ Transfer ${transfer_id} has been deleted and its share link revoked.`,
            },
          ],
        };
      }

      case 'get_download_link': {
        const { share_token, password } = args as { share_token: string; password?: string };
        const result = await client.getDownloadLink(share_token, password);

        return {
          content: [
            {
              type: 'text',
              text: `**Download Link**

**File:** ${result.fileName}
**Size:** ${formatBytes(result.fileSize)}
**Direct Download:** ${result.downloadUrl}

This link is valid for ${formatDuration(result.validFor)}.`,
            },
          ],
        };
      }

      default:
        throw new McpError(ErrorCode.MethodNotFound, `Unknown tool: ${name}`);
    }
  } catch (error) {
    if (error instanceof McpError) {
      throw error;
    }
    
    const message = error instanceof Error ? error.message : 'Unknown error occurred';
    throw new McpError(ErrorCode.InternalError, message);
  }
});

/**
 * Start the MCP server
 */
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error('ZipShare MCP Server running');
}

main().catch((error) => {
  console.error('Failed to start server:', error);
  process.exit(1);
});
