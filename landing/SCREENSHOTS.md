# Adding Screenshots to Landing Page

## Current Status

The landing page now has a **"See It In Action"** section with a placeholder for application screenshots.

## How to Add Screenshots

### Step 1: Prepare Your Screenshots

Create high-quality screenshots of your application:
- **Dashboard/Transfer Interface**: Main file transfer UI
- **Real-Time Progress**: Show live progress tracking
- **File Management**: File list/management view
- **Settings/API**: Settings or API documentation page

**Recommended Specs**:
- Format: PNG or WebP
- Resolution: 1920x1080 or higher (for retina displays)
- File size: Optimized (< 500KB per image)
- Style: Clean, modern, professional

### Step 2: Save Screenshots

Save your screenshots in a `screenshots/` folder:
```
landing/
├── index.html
├── screenshots/
│   ├── dashboard.png
│   ├── progress-view.png
│   ├── file-management.png
│   └── api-settings.png
```

### Step 3: Update HTML

Replace the placeholder in `index.html` (around line 850):

**Current (Placeholder)**:
```html
<div class="demo-placeholder">
    <svg>...</svg>
    <h3>Application Screenshot</h3>
    <p>Real-time file transfer interface...</p>
</div>
```

**Replace With**:
```html
<img src="screenshots/dashboard.png" alt="FlowTransfer Dashboard - Real-time file transfer interface" class="demo-screenshot-img">
```

### Step 4: Add Multiple Screenshots (Optional)

You can create a carousel or multiple screenshot views:

```html
<div class="demo-screenshot">
    <div class="screenshot-carousel">
        <img src="screenshots/dashboard.png" alt="Dashboard" class="active">
        <img src="screenshots/progress-view.png" alt="Progress View">
        <img src="screenshots/file-management.png" alt="File Management">
    </div>
    <div class="screenshot-nav">
        <button class="prev">←</button>
        <button class="next">→</button>
    </div>
</div>
```

### Step 5: Optimize Images

Before uploading, optimize your screenshots:
- Use tools like TinyPNG or Squoosh
- Convert to WebP format for better compression
- Ensure images are responsive (max-width: 100%)

## Screenshot Ideas

### Primary Screenshot (Main Demo)
- **File Transfer in Progress**: Show a file being uploaded with:
  - Real-time progress bar
  - Transfer speed (MB/s)
  - ETA
  - File name and size
  - Multiple files in queue

### Secondary Screenshots (Feature Highlights)
- **Dashboard View**: Overview of recent transfers
- **Share Link Creation**: Password protection, expiration settings
- **API Documentation**: Show developer-friendly API
- **Team Workspace**: Collaboration features

## Best Practices

1. **Show Real Data**: Use realistic file names, sizes, and progress
2. **Highlight Key Features**: Make sure real-time progress is visible
3. **Clean UI**: Remove any sensitive data, use mock data
4. **Consistent Design**: Match your brand colors and style
5. **Mobile Responsive**: Consider mobile screenshots too

## Current Placeholder

The current placeholder shows:
- Browser window mockup
- Placeholder content area
- Feature highlights below

This gives visitors a sense of what to expect while you're building the application.
