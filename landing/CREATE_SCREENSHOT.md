# How to Create Screenshot from Mockup

## Quick Method

1. **Open the mockup**:
   ```bash
   open landing/screenshots/app-mockup.html
   ```
   Or open `landing/screenshots/app-mockup.html` in your browser

2. **Take a screenshot**:
   - **macOS**: Cmd + Shift + 4, then select the browser window
   - **Windows**: Win + Shift + S, then select the area
   - **Linux**: Use screenshot tool (Print Screen)

3. **Save the screenshot**:
   - Save as `landing/screenshots/dashboard.png`
   - Recommended: 1920x1080 resolution or higher
   - Optimize with TinyPNG or similar tool

4. **Update the landing page**:
   - Replace the placeholder in `landing/index.html`
   - Find the `<div class="demo-placeholder">` section
   - Replace with: `<img src="screenshots/dashboard.png" alt="ZipShare Dashboard" class="demo-screenshot-img">`

## Alternative: Use Browser DevTools

1. Open `app-mockup.html` in Chrome/Firefox
2. Open DevTools (F12)
3. Use Device Toolbar (Cmd/Ctrl + Shift + M)
4. Set viewport to 1920x1080
5. Take screenshot using browser's screenshot tool
6. Save as PNG

## What the Mockup Shows

- **Clean, modern interface** matching your landing page design
- **Real-time progress bars** with live updates
- **Transfer speed and ETA** displayed
- **Multiple file transfers** in progress
- **Professional file icons** and status indicators
- **Upload area** with drag & drop

This gives visitors a clear picture of what ZipShare will look like!
