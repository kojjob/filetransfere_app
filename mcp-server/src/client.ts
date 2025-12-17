/**
 * ZipShare API Client
 * 
 * Handles all communication with the ZipShare API for the MCP server.
 */

import * as fs from 'fs';
import * as path from 'path';
import FormData from 'form-data';
import mime from 'mime-types';

interface UploadOptions {
  recipientEmail?: string;
  message?: string;
  password?: string;
  expiresIn?: number;
  maxDownloads?: number;
}

interface UploadResult {
  id: string;
  fileName: string;
  fileSize: number;
  shareUrl: string;
  expiresAt: string;
}

interface MultiUploadResult extends UploadResult {
  fileCount: number;
  totalSize: number;
  files: Array<{ name: string; size: number }>;
}

interface TransferStatus {
  id: string;
  fileName: string;
  fileSize: number;
  status: string;
  progress: number;
  downloadCount: number;
  maxDownloads?: number;
  createdAt: string;
  expiresAt: string;
  shareUrl?: string;
}

interface ListTransfersResult {
  transfers: TransferStatus[];
  total: number;
}

interface DownloadLinkResult {
  fileName: string;
  fileSize: number;
  downloadUrl: string;
  validFor: number;
}

export class ZipShareClient {
  private baseUrl: string;
  private apiKey: string;

  constructor(baseUrl: string, apiKey: string) {
    this.baseUrl = baseUrl.replace(/\/$/, '');
    this.apiKey = apiKey;
  }

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const headers: Record<string, string> = {
      'Authorization': `Bearer ${this.apiKey}`,
      ...(options.headers as Record<string, string> || {}),
    };

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: response.statusText }));
      throw new Error(error.message || `API request failed: ${response.status}`);
    }

    return response.json() as T;
  }

  /**
   * Upload a single file
   */
  async uploadFile(filePath: string, options: UploadOptions = {}): Promise<UploadResult> {
    // Validate file exists
    if (!fs.existsSync(filePath)) {
      throw new Error(`File not found: ${filePath}`);
    }

    const stats = fs.statSync(filePath);
    const fileName = path.basename(filePath);
    const fileType = mime.lookup(filePath) || 'application/octet-stream';

    // Step 1: Initialize transfer
    const transfer = await this.request<{ id: string; upload_url: string }>('/api/transfers', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        file_name: fileName,
        file_size: stats.size,
        file_type: fileType,
      }),
    });

    // Step 2: Upload the file in chunks
    await this.uploadFileChunks(transfer.id, filePath, stats.size);

    // Step 3: Create share link
    const share = await this.request<{
      token: string;
      url: string;
      expires_at: string;
    }>(`/api/transfers/${transfer.id}/share`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        password: options.password,
        expires_in: options.expiresIn ? options.expiresIn * 3600 : undefined,
        max_downloads: options.maxDownloads,
        recipient_email: options.recipientEmail,
        message: options.message,
      }),
    });

    return {
      id: transfer.id,
      fileName,
      fileSize: stats.size,
      shareUrl: share.url,
      expiresAt: share.expires_at,
    };
  }

  /**
   * Upload multiple files as a batch
   */
  async uploadFiles(filePaths: string[], options: UploadOptions = {}): Promise<MultiUploadResult> {
    // Validate all files exist
    const files: Array<{ path: string; name: string; size: number }> = [];
    let totalSize = 0;

    for (const filePath of filePaths) {
      if (!fs.existsSync(filePath)) {
        throw new Error(`File not found: ${filePath}`);
      }
      const stats = fs.statSync(filePath);
      const name = path.basename(filePath);
      files.push({ path: filePath, name, size: stats.size });
      totalSize += stats.size;
    }

    // Create batch transfer
    const batch = await this.request<{ id: string; transfers: Array<{ id: string; file_name: string }> }>(
      '/api/transfers/batch',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          files: files.map((f) => ({
            file_name: f.name,
            file_size: f.size,
            file_type: mime.lookup(f.path) || 'application/octet-stream',
          })),
        }),
      }
    );

    // Upload each file
    for (let i = 0; i < files.length; i++) {
      await this.uploadFileChunks(
        batch.transfers[i].id,
        files[i].path,
        files[i].size
      );
    }

    // Create share link for batch
    const share = await this.request<{
      token: string;
      url: string;
      expires_at: string;
    }>(`/api/batches/${batch.id}/share`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        password: options.password,
        expires_in: options.expiresIn ? options.expiresIn * 3600 : undefined,
        recipient_email: options.recipientEmail,
        message: options.message,
      }),
    });

    return {
      id: batch.id,
      fileName: `${files.length} files`,
      fileSize: totalSize,
      fileCount: files.length,
      totalSize,
      files: files.map((f) => ({ name: f.name, size: f.size })),
      shareUrl: share.url,
      expiresAt: share.expires_at,
    };
  }

  /**
   * Upload file in chunks with progress
   */
  private async uploadFileChunks(
    transferId: string,
    filePath: string,
    fileSize: number
  ): Promise<void> {
    const CHUNK_SIZE = 5 * 1024 * 1024; // 5MB chunks
    const totalChunks = Math.ceil(fileSize / CHUNK_SIZE);
    const fileHandle = fs.openSync(filePath, 'r');

    try {
      for (let chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        const start = chunkIndex * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, fileSize);
        const chunkSize = end - start;

        // Read chunk
        const buffer = Buffer.alloc(chunkSize);
        fs.readSync(fileHandle, buffer, 0, chunkSize, start);

        // Get presigned URL for chunk
        const { presigned_url } = await this.request<{ presigned_url: string }>(
          `/api/transfers/${transferId}/upload/presigned?chunk=${chunkIndex}`
        );

        // Upload chunk to S3
        await fetch(presigned_url, {
          method: 'PUT',
          body: buffer,
          headers: {
            'Content-Length': chunkSize.toString(),
          },
        });

        // Mark chunk complete
        await this.request(`/api/transfers/${transferId}/chunks/${chunkIndex}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ status: 'completed' }),
        });
      }

      // Complete the transfer
      await this.request(`/api/transfers/${transferId}/upload/complete`, {
        method: 'POST',
      });
    } finally {
      fs.closeSync(fileHandle);
    }
  }

  /**
   * Get status of a transfer
   */
  async getTransferStatus(transferId: string): Promise<TransferStatus> {
    // Extract ID from URL if needed
    const id = transferId.includes('/') 
      ? transferId.split('/').pop()! 
      : transferId;

    return this.request<TransferStatus>(`/api/transfers/${id}`);
  }

  /**
   * List recent transfers
   */
  async listTransfers(options: {
    limit?: number;
    status?: string;
  } = {}): Promise<ListTransfersResult> {
    const params = new URLSearchParams();
    if (options.limit) params.set('limit', options.limit.toString());
    if (options.status) params.set('status', options.status);

    const query = params.toString();
    return this.request<ListTransfersResult>(
      `/api/transfers${query ? `?${query}` : ''}`
    );
  }

  /**
   * Delete a transfer
   */
  async deleteTransfer(transferId: string): Promise<void> {
    await this.request(`/api/transfers/${transferId}`, {
      method: 'DELETE',
    });
  }

  /**
   * Get download link for a share
   */
  async getDownloadLink(
    shareToken: string,
    password?: string
  ): Promise<DownloadLinkResult> {
    return this.request<DownloadLinkResult>(`/s/${shareToken}/download`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password }),
    });
  }
}

