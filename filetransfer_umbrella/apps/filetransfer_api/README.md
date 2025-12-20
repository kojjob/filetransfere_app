# ZipShare API

REST API for the ZipShare file transfer platform.

## Endpoints

### Authentication
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - User login
- `POST /api/auth/logout` - User logout
- `GET /api/auth/me` - Current user info

### Transfers
- `GET /api/transfers` - List transfers
- `POST /api/transfers` - Create transfer
- `GET /api/transfers/:id` - Get transfer details
- `DELETE /api/transfers/:id` - Delete transfer

### Share Links
- `POST /api/transfers/:id/share` - Create share link
- `GET /api/shares` - List share links
- `GET /s/:token` - Access shared file (public)

### Waitlist
- `POST /api/waitlist` - Join waitlist (public)
