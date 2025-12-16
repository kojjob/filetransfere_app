# Deployment Quick Start Guide

**Time to deploy**: ~2-4 hours  
**Priority**: Start with Critical items only

---

## 🚨 Critical Items (Do These First)

### 1. Fix CORS (5 minutes)
**File**: `filetransfer_umbrella/apps/filetransfer_web/lib/filetransfer_web/plugs/cors.ex`

Replace line 11:
```elixir
# OLD (INSECURE):
|> put_resp_header("access-control-allow-origin", "*")

# NEW (SECURE):
|> put_resp_header("access-control-allow-origin", System.get_env("ALLOWED_ORIGINS", "*"))
```

Set environment variable:
```bash
export ALLOWED_ORIGINS=https://zishare.com,https://www.zishare.com
```

### 2. Update API URL (2 minutes)
**File**: `landing/index.html` (line ~988)

Replace:
```javascript
// OLD:
const apiUrl = 'http://localhost:4000/api/waitlist';

// NEW:
const apiUrl = window.location.hostname === 'localhost' 
  ? 'http://localhost:4000/api/waitlist'
  : 'https://api.zishare.com/api/waitlist';
```

### 3. Generate Secret Key (1 minute)
```bash
cd filetransfer_umbrella
mix phx.gen.secret
# Copy the output and set as SECRET_KEY_BASE environment variable
```

### 4. Set Production Environment Variables
```bash
# Required
export SECRET_KEY_BASE=<generated_secret>
export DATABASE_URL=postgres://user:pass@host:5432/dbname
export PHX_HOST=api.zishare.com
export ALLOWED_ORIGINS=https://zishare.com

# Optional but recommended
export PORT=4000
export POOL_SIZE=10
```

### 5. Run Database Migrations
```bash
cd filetransfer_umbrella
MIX_ENV=prod mix ecto.migrate
```

---

## 📋 Deployment Steps

### Option A: Fly.io (Recommended for Elixir)

1. **Install Fly CLI**
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. **Login and Launch**
   ```bash
   fly auth login
   cd filetransfer_umbrella
   fly launch
   ```

3. **Set Secrets**
   ```bash
   fly secrets set SECRET_KEY_BASE=<your_secret>
   fly secrets set DATABASE_URL=<your_db_url>
   fly secrets set ALLOWED_ORIGINS=https://zishare.com
   fly secrets set PHX_HOST=api.zishare.com
   ```

4. **Deploy**
   ```bash
   fly deploy
   ```

### Option B: Railway

1. **Connect Repository**
   - Go to railway.app
   - New Project → Deploy from GitHub
   - Select your repository

2. **Configure**
   - Add PostgreSQL service
   - Set environment variables
   - Deploy

### Option C: Render

1. **Create Web Service**
   - Connect GitHub repository
   - Build command: `cd filetransfer_umbrella && mix deps.get && mix compile`
   - Start command: `cd filetransfer_umbrella && mix phx.server`

2. **Add PostgreSQL**
   - Create PostgreSQL database
   - Copy DATABASE_URL

3. **Set Environment Variables**
   - Add all required variables
   - Deploy

---

## 🌐 Landing Page Deployment

### Option A: Netlify (Easiest)

1. **Connect Repository**
   - Go to netlify.com
   - New site from Git
   - Select repository

2. **Configure**
   - Build command: (leave empty - static site)
   - Publish directory: `landing`
   - Deploy

3. **Custom Domain**
   - Add custom domain
   - Configure DNS
   - SSL auto-configured

### Option B: Vercel

1. **Install Vercel CLI**
   ```bash
   npm i -g vercel
   ```

2. **Deploy**
   ```bash
   cd landing
   vercel
   ```

3. **Configure Domain**
   - Add domain in Vercel dashboard
   - Update DNS records

### Option C: Cloudflare Pages

1. **Connect Repository**
   - Go to Cloudflare Dashboard
   - Pages → Create a project
   - Connect GitHub

2. **Configure**
   - Build command: (empty)
   - Build output: `landing`
   - Deploy

---

## ✅ Pre-Deployment Checklist

- [ ] CORS fixed (not allowing `*`)
- [ ] API URL updated in landing page
- [ ] SECRET_KEY_BASE generated and set
- [ ] DATABASE_URL configured
- [ ] ALLOWED_ORIGINS set
- [ ] Database migrations run
- [ ] Test form submission locally
- [ ] Environment variables documented

---

## 🧪 Testing After Deployment

### 1. Test Landing Page
```bash
curl https://zishare.com
# Should return HTML
```

### 2. Test API Endpoint
```bash
curl -X POST https://api.zishare.com/api/waitlist \
  -H "Content-Type: application/json" \
  -H "Origin: https://zishare.com" \
  -d '{"waitlist_entry":{"email":"test@example.com"}}'
```

### 3. Test Form Submission
- Open landing page in browser
- Fill out waitlist form
- Submit and verify success message
- Check database for entry

### 4. Test CORS
```bash
# Should work
curl -H "Origin: https://zishare.com" \
     -X OPTIONS https://api.zishare.com/api/waitlist

# Should fail (if CORS properly configured)
curl -H "Origin: https://evil.com" \
     -X OPTIONS https://api.zishare.com/api/waitlist
```

---

## 🐛 Common Issues

### Issue: CORS errors
**Solution**: Check ALLOWED_ORIGINS includes your landing page domain

### Issue: Database connection fails
**Solution**: Verify DATABASE_URL is correct and database is accessible

### Issue: Form submission fails
**Solution**: 
- Check browser console for errors
- Verify API URL is correct
- Check API logs for errors

### Issue: 500 errors
**Solution**: 
- Check SECRET_KEY_BASE is set
- Verify all environment variables
- Check application logs

---

## 📊 Post-Deployment Monitoring

1. **Check Application Logs**
   ```bash
   # Fly.io
   fly logs
   
   # Railway
   # View in dashboard
   
   # Render
   # View in dashboard
   ```

2. **Monitor Database**
   - Check connection pool
   - Monitor query performance
   - Set up backups

3. **Set Up Alerts**
   - Uptime monitoring (UptimeRobot)
   - Error tracking (Sentry)
   - Log aggregation (Logtail)

---

## 🎯 Next Steps After Basic Deployment

Once basic deployment works:

1. Add rate limiting (prevent abuse)
2. Add CAPTCHA (prevent bots)
3. Add security headers
4. Set up error tracking
5. Add email confirmations
6. Set up monitoring

See `DEPLOYMENT_CHECKLIST.md` for full list.

---

## 📚 Resources

- [Fly.io Elixir Guide](https://fly.io/docs/elixir/getting-started/)
- [Phoenix Deployment](https://hexdocs.pm/phoenix/deployment.html)
- [Netlify Deployment](https://docs.netlify.com/)
- [Vercel Deployment](https://vercel.com/docs)

---

**Estimated Time**: 2-4 hours for basic deployment  
**Cost**: ~$5-20/month (depending on hosting choices)
