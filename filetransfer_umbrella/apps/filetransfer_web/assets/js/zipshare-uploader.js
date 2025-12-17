/**
 * ZipShare File Uploader
 * 
 * A production-ready file uploader with:
 * - Chunked uploads for large files
 * - Real-time progress via WebSockets
 * - Automatic retry on failures
 * - Pause/Resume support
 */

export class ZipShareUploader {
  constructor(options = {}) {
    this.apiUrl = options.apiUrl || '';
    this.socketUrl = options.socketUrl || this.apiUrl.replace('http', 'ws') + '/socket';
    this.token = options.token;
    this.chunkSize = options.chunkSize || 5 * 1024 * 1024; // 5MB
    this.maxRetries = options.maxRetries || 3;
    this.retryDelay = options.retryDelay || 1000;
    
    this.onProgress = options.onProgress || (() => {});
    this.onComplete = options.onComplete || (() => {});
    this.onError = options.onError || (() => {});
    this.onStart = options.onStart || (() => {});
    
    this.socket = null;
    this.channel = null;
    this.transfer = null;
    this.isPaused = false;
    this.currentChunk = 0;
    this.uploadedParts = [];
    this.abortController = null;
  }

  async upload(file) {
    this.file = file;
    this.isPaused = false;
    this.currentChunk = 0;
    this.uploadedParts = [];
    this.abortController = new AbortController();

    try {
      this.transfer = await this.createTransfer(file);
      this.onStart(this.transfer);
      await this.connectWebSocket();
      const { upload_id, key } = await this.initMultipartUpload();
      this.uploadId = upload_id;
      this.storageKey = key;

      const totalChunks = Math.ceil(file.size / this.chunkSize);
      
      for (let i = this.currentChunk; i < totalChunks; i++) {
        if (this.isPaused) return { paused: true, currentChunk: i };

        const chunk = this.getChunk(file, i);
        const result = await this.uploadChunk(chunk, i + 1);
        this.uploadedParts.push({ part_number: i + 1, etag: result.etag });
        this.currentChunk = i + 1;

        const progress = {
          loaded: Math.min((i + 1) * this.chunkSize, file.size),
          total: file.size,
          percent: Math.round(((i + 1) / totalChunks) * 100),
          chunk: i + 1,
          totalChunks,
          speed: result.speed || 0,
          eta: result.eta || null
        };
        this.onProgress(progress);
      }

      const completed = await this.completeUpload();
      this.onComplete(completed);
      this.disconnect();
      return completed;
    } catch (error) {
      this.onError(error);
      this.disconnect();
      throw error;
    }
  }

  pause() { this.isPaused = true; }
  
  async resume() {
    if (!this.isPaused || !this.file) throw new Error('No paused upload');
    this.isPaused = false;
    return this.upload(this.file);
  }

  async abort() {
    this.abortController?.abort();
    if (this.transfer && this.uploadId) {
      await this.request('POST', `/transfers/${this.transfer.id}/upload/abort`);
    }
    this.disconnect();
  }

  async createTransfer(file) {
    const response = await this.request('POST', '/transfers', {
      file_name: file.name, file_size: file.size, file_type: file.type || 'application/octet-stream'
    });
    return response.data;
  }

  async initMultipartUpload() {
    const response = await this.request('POST', `/transfers/${this.transfer.id}/upload/init`);
    return response.data;
  }

  async uploadChunk(chunk, partNumber) {
    const startTime = Date.now();
    for (let attempt = 0; attempt < this.maxRetries; attempt++) {
      try {
        const response = await this.request('POST', `/transfers/${this.transfer.id}/upload/chunk`, chunk, {
          headers: { 'Content-Type': 'application/octet-stream' },
          params: { part_number: partNumber }
        });
        const elapsed = (Date.now() - startTime) / 1000;
        return { ...response.data, speed: chunk.size / elapsed, eta: this.calculateETA(chunk.size / elapsed) };
      } catch (error) {
        if (attempt === this.maxRetries - 1) throw error;
        await this.delay(this.retryDelay * (attempt + 1));
      }
    }
  }

  async completeUpload() {
    const response = await this.request('POST', `/transfers/${this.transfer.id}/upload/complete`, { parts: this.uploadedParts });
    return response.data;
  }

  getChunk(file, index) {
    const start = index * this.chunkSize;
    return file.slice(start, Math.min(start + this.chunkSize, file.size));
  }

  calculateETA(speed) {
    if (!speed) return null;
    const remaining = this.file.size - (this.currentChunk * this.chunkSize);
    return Math.round(remaining / speed);
  }

  async connectWebSocket() {
    return new Promise((resolve) => {
      if (typeof Phoenix === 'undefined') { resolve(); return; }
      this.socket = new Phoenix.Socket(this.socketUrl, { params: { user_id: 'current-user' } });
      this.socket.connect();
      this.channel = this.socket.channel(`transfer:${this.transfer.id}`, {});
      this.channel.on('transfer:progress', (p) => this.onProgress({ loaded: p.total_bytes_uploaded, total: this.file.size, percent: p.progress_percent, speed: p.speed_bytes_per_sec, eta: p.eta_seconds }));
      this.channel.on('transfer:complete', (p) => this.onComplete(p));
      this.channel.on('transfer:error', (p) => this.onError(new Error(p.error)));
      this.channel.join().receive('ok', () => resolve()).receive('error', () => resolve());
    });
  }

  disconnect() {
    this.channel?.leave();
    this.socket?.disconnect();
    this.channel = null;
    this.socket = null;
  }

  async request(method, path, body, options = {}) {
    const url = new URL(path, this.apiUrl);
    if (options.params) Object.entries(options.params).forEach(([k, v]) => url.searchParams.append(k, v));
    const headers = { 'Accept': 'application/json', ...(options.headers || {}) };
    if (this.token) headers['Authorization'] = `Bearer ${this.token}`;
    if (body && !(body instanceof Blob) && !headers['Content-Type']) headers['Content-Type'] = 'application/json';
    const response = await fetch(url.toString(), {
      method, headers,
      body: body instanceof Blob ? body : (body ? JSON.stringify(body) : undefined),
      signal: this.abortController?.signal,
      credentials: 'include'
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({ message: response.statusText }));
      throw new Error(error.message || `Request failed: ${response.status}`);
    }
    return response.json();
  }

  delay(ms) { return new Promise(resolve => setTimeout(resolve, ms)); }
}

export function createDropZone(element, uploader, options = {}) {
  const { onDragEnter = () => {}, onDragLeave = () => {}, onDrop = () => {} } = options;
  element.addEventListener('dragover', (e) => { e.preventDefault(); e.stopPropagation(); });
  element.addEventListener('dragenter', (e) => { e.preventDefault(); element.classList.add('dragover'); onDragEnter(e); });
  element.addEventListener('dragleave', (e) => { e.preventDefault(); element.classList.remove('dragover'); onDragLeave(e); });
  element.addEventListener('drop', async (e) => {
    e.preventDefault();
    element.classList.remove('dragover');
    const files = Array.from(e.dataTransfer.files);
    onDrop(files);
    if (files.length > 0) await uploader.upload(files[0]);
  });
  return element;
}

export function formatBytes(bytes, decimals = 2) {
  if (bytes === 0) return '0 Bytes';
  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(decimals)) + ' ' + sizes[i];
}

export function formatTime(seconds) {
  if (!seconds || seconds < 0) return '--:--';
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, '0')}`;
}
