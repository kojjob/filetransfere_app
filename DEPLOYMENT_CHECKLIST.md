# Landing Page Deployment Checklist

**Status**: Pre-deployment  
**Last Updated**: December 2025

This checklist ensures your landing page is functional, secure, and production-ready.

---

## 🔒 Security (Critical)

### 1. CORS Configuration
- [ ] **Update CORS plug to restrict origins** (currently allows `*`)
  - File: `filetransfer_umbrella/apps/filetransfer_web/lib/filetransfer_web/plugs/cors.ex`
  - Change from `"*"` to specific domain(s)
  - Use environment variable: `ALLOWED_ORIGINS`
  - **Priority**: 🔴 Critical

### 2. Rate Limiting
- [ ] **Add rate limiting to waitlist endpoint**
  - Prevent spam/abuse
  - Suggested: 5 requests per IP per hour
  - Use `PlugAttack` or `Hammer` library
  - **Priority**: 🔴 Critical

### 3. Input Validation & Sanitization
- [ ] **Email validation** (already done in schema)
- [ ] **XSS prevention** (Phoenix auto-escapes, but verify)
- [ ] **SQL injection protection** (Ecto handles this)
- [ ] **File upload validation** (if adding file uploads later)
  - **Priority**: 🟡 High

### 4. Security Headers
- [ ] **Add security headers middleware**
  - Content-Security-Policy (CSP)
  - X-Frame-Options: DENY
  - X-Content-Type-Options: nosniff
  - Strict-Transport-Security (HSTS)
  - Use `Plug.SecureHeaders` or similar
  - **Priority**: 🟡 High

### 5. CAPTCHA/Bot Protection
- [ ] **Add reCAPTCHA v3 or hCaptcha**
  - Prevent bot submissions
  - Integrate with waitlist form
  - Verify on backend before saving
  - **Priority**: 🟡 High

### 6. Environment Variables
- [ ] **Move all secrets to environment variables**
  - `SECRET_KEY_BASE` (already configured)
  - `DATABASE_URL`
  - `ALLOWED_ORIGINS`
  - API keys, tokens
  - Never commit secrets to git
  - **Priority**: 🔴 Critical

### 7. HTTPS/SSL
- [ ] **Enable HTTPS in production**
  - Configure SSL certificates (Let's Encrypt)
  - Redirect HTTP → HTTPS
  - Update Phoenix endpoint config
  - **Priority**: 🔴 Critical

---

## ⚙️ Configuration

### 8. API URL Configuration
- [ ] **Update landing page API URL**
  - File: `landing/index.html` (line ~988)
  - Change from `http://localhost:4000` to production URL
  - Use environment variable or build-time config
  - **Priority**: 🔴 Critical

### 9. Production Database
- [ ] **Set up production PostgreSQL database**
  - Use managed service (AWS RDS, DigitalOcean, etc.)
  - Configure connection pooling
  - Set up database backups
  - **Priority**: 🔴 Critical

### 10. Database Migrations
- [ ] **Run migrations in production**
  ```bash
  MIX_ENV=prod mix ecto.migrate
  ```
  - **Priority**: 🔴 Critical

### 11. Phoenix Endpoint Configuration
- [ ] **Update production endpoint config**
  - File: `config/prod.exs` and `config/runtime.exs`
  - Set correct `host` and `port`
  - Configure SSL
  - Set `server: true` for releases
  - **Priority**: 🔴 Critical

### 12. Secret Key Base
- [ ] **Generate and set SECRET_KEY_BASE**
  ```bash
  mix phx.gen.secret
  ```
  - Store in environment variable
  - Never commit to git
  - **Priority**: 🔴 Critical

---

## 🚀 Deployment Infrastructure

### 13. Landing Page Hosting
- [ ] **Choose hosting provider**
  - Options: Netlify, Vercel, Cloudflare Pages, GitHub Pages
  - Configure custom domain
  - Set up SSL certificate
  - **Priority**: 🔴 Critical

### 14. Backend API Hosting
- [ ] **Choose hosting provider**
  - Options: Fly.io, Railway, Render, DigitalOcean, AWS
  - Configure environment variables
  - Set up process manager (systemd, supervisor)
  - **Priority**: 🔴 Critical

### 15. Domain Configuration
- [ ] **Set up custom domain(s)**
  - Landing page: `zishare.com` (or your domain)
  - API: `api.zishare.com` (or subdomain)
  - Configure DNS records
  - **Priority**: 🔴 Critical

### 16. CDN Configuration
- [ ] **Set up CDN for static assets** (optional but recommended)
  - Cloudflare, AWS CloudFront, etc.
  - Cache static files
  - **Priority**: 🟢 Medium

---

## 📊 Monitoring & Logging

### 17. Error Tracking
- [ ] **Set up error tracking**
  - Sentry, Rollbar, or similar
  - Track API errors
  - Monitor form submission failures
  - **Priority**: 🟡 High

### 18. Analytics
- [ ] **Add analytics to landing page**
  - Google Analytics, Plausible, or similar
  - Track form submissions
  - Monitor conversion rates
  - **Priority**: 🟢 Medium

### 19. Uptime Monitoring
- [ ] **Set up uptime monitoring**
  - UptimeRobot, Pingdom, or similar
  - Monitor API endpoint
  - Alert on downtime
  - **Priority**: 🟡 High

### 20. Logging
- [ ] **Configure production logging**
  - Structured logging (JSON format)
  - Log aggregation (Logtail, Datadog, etc.)
  - Set appropriate log levels
  - **Priority**: 🟡 High

---

## 🧪 Testing & Validation

### 21. End-to-End Testing
- [ ] **Test waitlist form submission**
  - Submit from landing page
  - Verify data saved in database
  - Test error handling
  - **Priority**: 🔴 Critical

### 22. CORS Testing
- [ ] **Verify CORS works correctly**
  - Test from landing page domain
  - Verify blocked from other domains
  - **Priority**: 🔴 Critical

### 23. Rate Limiting Testing
- [ ] **Test rate limiting**
  - Submit multiple requests quickly
  - Verify rate limit enforced
  - **Priority**: 🟡 High

### 24. Mobile Testing
- [ ] **Test on mobile devices**
  - Responsive design works
  - Form submission works
  - Touch interactions smooth
  - **Priority**: 🟡 High

### 25. Browser Compatibility
- [ ] **Test on major browsers**
  - Chrome, Firefox, Safari, Edge
  - Verify form works in all
  - **Priority**: 🟡 High

---

## 📧 Email & Notifications

### 26. Email Confirmation
- [ ] **Send confirmation email** (optional but recommended)
  - When user joins waitlist
  - Use SendGrid, Postmark, Resend, or AWS SES
  - Include unsubscribe link
  - **Priority**: 🟢 Medium

### 27. Admin Notifications
- [ ] **Notify admin of new waitlist entries** (optional)
  - Email or Slack notification
  - Include entry details
  - **Priority**: 🟢 Low

---

## 🔧 Performance Optimization

### 28. Static Asset Optimization
- [ ] **Minify and compress assets**
  - Minify CSS/JS
  - Compress images
  - Enable gzip/brotli compression
  - **Priority**: 🟢 Medium

### 29. Database Indexing
- [ ] **Add database indexes**
  - Index on `waitlist_entries.email` (already unique)
  - Index on `waitlist_entries.inserted_at` for queries
  - **Priority**: 🟢 Medium

### 30. Caching
- [ ] **Implement caching** (if needed)
  - Cache static responses
  - Cache database queries if high traffic
  - **Priority**: 🟢 Low (for MVP)

---

## 📝 Documentation

### 31. API Documentation
- [ ] **Document API endpoints**
  - Waitlist endpoint spec
  - Request/response formats
  - Error codes
  - **Priority**: 🟢 Medium

### 32. Deployment Documentation
- [ ] **Document deployment process**
  - Step-by-step deployment guide
  - Environment variables list
  - Troubleshooting guide
  - **Priority**: 🟢 Medium

---

## 🛡️ Compliance & Legal

### 33. Privacy Policy
- [ ] **Add privacy policy**
  - Explain data collection
  - GDPR compliance (if EU users)
  - Link in footer
  - **Priority**: 🟡 High

### 34. Terms of Service
- [ ] **Add terms of service**
  - Usage terms
  - Liability limitations
  - Link in footer
  - **Priority**: 🟢 Medium

### 35. Cookie Consent (if using analytics)
- [ ] **Add cookie consent banner**
  - GDPR compliance
  - Allow users to opt-out
  - **Priority**: 🟡 High (if EU users)

---

## 🔄 Backup & Recovery

### 36. Database Backups
- [ ] **Set up automated database backups**
  - Daily backups minimum
  - Test restore process
  - Store backups securely
  - **Priority**: 🟡 High

### 37. Disaster Recovery Plan
- [ ] **Document recovery procedures**
  - How to restore from backup
  - Contact information
  - Escalation procedures
  - **Priority**: 🟢 Medium

---

## 🎯 Post-Deployment

### 38. Smoke Tests
- [ ] **Run smoke tests after deployment**
  - Landing page loads
  - Form submission works
  - API responds correctly
  - **Priority**: 🔴 Critical

### 39. Performance Monitoring
- [ ] **Monitor performance metrics**
  - Response times
  - Error rates
  - Database query times
  - **Priority**: 🟡 High

### 40. User Feedback
- [ ] **Collect user feedback**
  - Monitor form submissions
  - Track conversion rates
  - Gather user testimonials
  - **Priority**: 🟢 Medium

---

## 📋 Quick Start Checklist (Minimum Viable Deployment)

**Must-have for basic functionality:**

1. ✅ Update API URL in landing page
2. ✅ Secure CORS configuration
3. ✅ Set up production database
4. ✅ Run database migrations
5. ✅ Configure SECRET_KEY_BASE
6. ✅ Deploy landing page
7. ✅ Deploy backend API
8. ✅ Set up custom domain + SSL
9. ✅ Test form submission
10. ✅ Add rate limiting

**Everything else can be added incrementally.**

---

## 🚨 Security Priority Summary

| Priority | Items | Status |
|----------|-------|--------|
| 🔴 Critical | CORS, Rate Limiting, HTTPS, Secrets, API URL | ⚠️ Must fix before launch |
| 🟡 High | CAPTCHA, Security Headers, Error Tracking, Backups | 📅 Fix within first week |
| 🟢 Medium | Analytics, Email, Performance | 📅 Nice to have |
| ⚪ Low | Advanced features | 📅 Future enhancements |

---

## 📚 Resources

- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [Elixir Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Let's Encrypt](https://letsencrypt.org/)

---

**Next Steps**: Start with the "Quick Start Checklist" items marked as critical, then work through the rest based on priority.
