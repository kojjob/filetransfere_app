# FlowTransfer

> **Real-time file transfer SaaS built with Elixir/Phoenix**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/Elixir-1.15+-purple.svg)](https://elixir-lang.org/)
[![Phoenix](https://img.shields.io/badge/Phoenix-1.8+-red.svg)](https://www.phoenixframework.org/)

FlowTransfer is a modern, high-performance file transfer service that provides real-time progress tracking, resumable uploads, and developer-friendly APIs. Built on Elixir and Phoenix for maximum concurrency and reliability.

---

## 🚀 Features

### Core Features
- **Real-Time Progress Tracking** - WebSocket-powered live updates with speed and ETA
- **Resumable Uploads** - Never lose progress with intelligent chunked uploads
- **Large File Support** - Handle GB+ files seamlessly with 5MB chunked transfers
- **Developer-First API** - REST and WebSocket APIs for automation
- **Secure Sharing** - Password protection, expiration dates, and download limits
- **Team Collaboration** - Workspaces, shared folders, and team management

### Technical Highlights
- **Elixir/Phoenix** - Built for concurrency and fault tolerance
- **WebSocket Channels** - Real-time bidirectional communication
- **PostgreSQL** - Reliable data persistence
- **S3-Compatible Storage** - Scalable file storage
- **CORS Support** - Cross-origin API access
- **Rate Limiting** - Protection against abuse

---

## 📋 Table of Contents

- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Development](#-development)
- [API Documentation](#-api-documentation)
- [Deployment](#-deployment)
- [Testing](#-testing)
- [Contributing](#-contributing)
- [Documentation](#-documentation)
- [License](#-license)

---

## 🛠 Tech Stack

### Backend
- **Elixir** 1.15+ - Functional, concurrent programming language
- **Phoenix** 1.8+ - Web framework
- **Phoenix LiveView** - Real-time UI updates
- **Ecto** - Database wrapper and query generator
- **PostgreSQL** - Primary database
- **Bandit** - HTTP server

### Frontend
- **HTML/CSS/JavaScript** - Landing page
- **Tailwind CSS** - Utility-first CSS framework
- **WebSocket** - Real-time communication

### Infrastructure
- **PostgreSQL** - Database
- **S3-Compatible Storage** - File storage (Backblaze B2, AWS S3, etc.)
- **CDN** - Cloudflare (optional)

---

## 📁 Project Structure

```
filetransfere_app/
├── filetransfer_umbrella/          # Elixir/Phoenix umbrella project
│   ├── apps/
│   │   ├── filetransfer_core/     # Core business logic & database
│   │   │   ├── lib/
│   │   │   │   ├── accounts/       # User authentication
│   │   │   │   ├── transfers/      # File transfer logic
│   │   │   │   ├── waitlist/       # Waitlist management
│   │   │   │   └── repo.ex         # Ecto repository
│   │   │   └── priv/repo/migrations/  # Database migrations
│   │   ├── filetransfer_web/       # Phoenix web application
│   │   │   ├── lib/
│   │   │   │   ├── controllers/    # API controllers
│   │   │   │   ├── plugs/          # CORS, auth, rate limiting
│   │   │   │   └── router.ex       # Routes
│   │   │   └── assets/             # Frontend assets
│   │   └── filetransfer_api/       # API application (future)
│   ├── config/                     # Configuration files
│   └── mix.exs                     # Umbrella dependencies
├── landing/                        # Landing page
│   ├── index.html                  # Main landing page
│   └── screenshots/                # App screenshots
├── RESEARCH_REPORT.md              # Market research
├── COMPETITIVE_ANALYSIS.md         # Competitive analysis
├── COST_ANALYSIS.md                # Cost breakdown
├── PRICING_ANALYSIS.md             # Pricing strategy
├── DEPLOYMENT_CHECKLIST.md         # Deployment tasks
├── DEPLOYMENT_QUICK_START.md       # Quick deployment guide
└── README.md                       # This file
```

---

## 🚀 Getting Started

### Prerequisites

- **Elixir** 1.15+ ([Install](https://elixir-lang.org/install.html))
- **Erlang/OTP** 26+ (comes with Elixir)
- **PostgreSQL** 12+ ([Install](https://www.postgresql.org/download/))
- **Node.js** 18+ (for assets)
- **Git**

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/kojjob/filetransfere_app.git
   cd filetransfere_app
   ```

2. **Install dependencies**
   ```bash
   cd filetransfer_umbrella
   mix deps.get
   ```

3. **Set up the database**
   ```bash
   # Create database
   mix ecto.create
   
   # Run migrations
   mix ecto.migrate
   ```

4. **Install frontend dependencies** (if needed)
   ```bash
   cd apps/filetransfer_web/assets
   npm install  # or yarn install
   ```

5. **Start the Phoenix server**
   ```bash
   cd filetransfer_umbrella
   mix phx.server
   ```

6. **Visit the application**
   - API: http://localhost:4000
   - Landing page: Open `landing/index.html` in a browser

---

## 💻 Development

### Running the Server

```bash
cd filetransfer_umbrella
mix phx.server
```

The API will be available at `http://localhost:4000`

### Database Setup

```bash
# Create database
mix ecto.create

# Run migrations
mix ecto.migrate

# Rollback migration
mix ecto.rollback

# Reset database (drops, creates, migrates)
mix ecto.reset
```

### Interactive Console

```bash
# Start IEx with Phoenix
iex -S mix phx.server

# Example: Query waitlist entries
alias FiletransferCore.Waitlist
Waitlist.list_waitlist_entries()
```

### Code Formatting

```bash
# Format all code
mix format

# Check formatting
mix format --check-formatted
```

### Running Tests

```bash
# Run all tests
mix test

# Run tests for specific app
cd apps/filetransfer_web
mix test

# Run with coverage
MIX_ENV=test mix test --cover
```

---

## 📡 API Documentation

### Authentication Endpoints

#### Register User
```http
POST /api/auth/register
Content-Type: application/json

{
  "user": {
    "email": "user@example.com",
    "name": "John Doe",
    "password": "secure_password"
  }
}
```

#### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "secure_password"
}
```

#### Get Current User
```http
GET /api/auth/me
Authorization: Bearer <token>
```

#### Logout
```http
POST /api/auth/logout
Authorization: Bearer <token>
```

### Waitlist Endpoint

#### Join Waitlist
```http
POST /api/waitlist
Content-Type: application/json

{
  "waitlist_entry": {
    "email": "user@example.com",
    "name": "John Doe",
    "use_case": "Video editing"
  }
}
```

**Response:**
```json
{
  "status": "success",
  "message": "Successfully added to waitlist!",
  "data": {
    "id": "...",
    "email": "user@example.com"
  }
}
```

### Error Responses

```json
{
  "status": "error",
  "message": "Error description",
  "errors": {
    "email": ["has already been taken"]
  }
}
```

---

## 🚢 Deployment

### Quick Deployment

See [DEPLOYMENT_QUICK_START.md](./DEPLOYMENT_QUICK_START.md) for step-by-step deployment instructions.

### Deployment Checklist

See [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) for a comprehensive list of deployment tasks.

### Security Implementation

See [DEPLOYMENT_SECURITY_IMPLEMENTATION.md](./DEPLOYMENT_SECURITY_IMPLEMENTATION.md) for security configuration.

### Environment Variables

Required for production:

```bash
# Database
DATABASE_URL=postgres://user:password@host:5432/database

# Phoenix
SECRET_KEY_BASE=<generate with: mix phx.gen.secret>
PHX_HOST=api.yourdomain.com
PORT=4000

# CORS
ALLOWED_ORIGINS=https://yourdomain.com,https://www.yourdomain.com

# Optional
POOL_SIZE=10
```

### Deployment Options

- **Fly.io** - Recommended for Elixir apps ([Guide](https://fly.io/docs/elixir/getting-started/))
- **Railway** - Simple deployment ([railway.app](https://railway.app))
- **Render** - Managed hosting ([render.com](https://render.com))
- **DigitalOcean** - VPS hosting ([digitalocean.com](https://digitalocean.com))

### Landing Page Deployment

- **Netlify** - Static site hosting ([netlify.com](https://netlify.com))
- **Vercel** - Fast static hosting ([vercel.com](https://vercel.com))
- **Cloudflare Pages** - CDN-powered hosting ([pages.cloudflare.com](https://pages.cloudflare.com))

---

## 🧪 Testing

### Running Tests

```bash
# Run all tests
mix test

# Run specific test file
mix test test/filetransfer_web/controllers/waitlist_controller_test.exs

# Run with verbose output
mix test --trace
```

### Test Coverage

```bash
# Generate coverage report
MIX_ENV=test mix test --cover
```

### Manual Testing

#### Test Waitlist API

```bash
curl -X POST http://localhost:4000/api/waitlist \
  -H "Content-Type: application/json" \
  -d '{
    "waitlist_entry": {
      "email": "test@example.com",
      "name": "Test User",
      "use_case": "Testing"
    }
  }'
```

#### Test Authentication

```bash
# Register
curl -X POST http://localhost:4000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "user": {
      "email": "test@example.com",
      "name": "Test User",
      "password": "password123"
    }
  }'

# Login
curl -X POST http://localhost:4000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
```

---

## 📚 Documentation

### Project Documentation

- **[Research Report](./RESEARCH_REPORT.md)** - Market research and opportunities
- **[Competitive Analysis](./COMPETITIVE_ANALYSIS.md)** - Competitor comparison
- **[Cost Analysis](./COST_ANALYSIS.md)** - Infrastructure and operational costs
- **[Pricing Analysis](./PRICING_ANALYSIS.md)** - Pricing strategy and positioning
- **[Waitlist Setup](./WAITLIST_SETUP.md)** - Waitlist implementation guide
- **[Deployment Checklist](./DEPLOYMENT_CHECKLIST.md)** - Complete deployment tasks
- **[Deployment Quick Start](./DEPLOYMENT_QUICK_START.md)** - Fast deployment guide
- **[Security Implementation](./DEPLOYMENT_SECURITY_IMPLEMENTATION.md)** - Security setup

### External Resources

- [Elixir Documentation](https://hexdocs.pm/elixir/)
- [Phoenix Documentation](https://hexdocs.pm/phoenix/)
- [Ecto Documentation](https://hexdocs.pm/ecto/)
- [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view/)

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
4. **Run tests**
   ```bash
   mix test
   mix format
   ```
5. **Commit your changes**
   ```bash
   git commit -m "feat: Add amazing feature"
   ```
6. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
7. **Open a Pull Request**

### Commit Message Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `style:` - Code style changes
- `refactor:` - Code refactoring
- `test:` - Test additions/changes
- `chore:` - Maintenance tasks

---

## 📊 Project Status

### ✅ Completed

- [x] Project structure setup
- [x] Database schema and migrations
- [x] User authentication system
- [x] Waitlist email collection
- [x] Landing page with waitlist form
- [x] CORS support
- [x] Market research and analysis
- [x] Pricing strategy
- [x] Deployment documentation

### 🚧 In Progress

- [ ] Chunked file upload system
- [ ] WebSocket progress tracking
- [ ] S3 storage integration
- [ ] Share link generation
- [ ] REST API endpoints
- [ ] Frontend React application

### 📅 Planned

- [ ] Payment integration (Stripe)
- [ ] Zapier/Make.com integrations
- [ ] Mobile apps
- [ ] Admin dashboard
- [ ] Email notifications
- [ ] Advanced analytics

---

## 💰 Pricing

### Current Pricing Structure

| Tier | Price | Transfer/Month | Max File Size | API Calls | Team Size |
|------|-------|----------------|---------------|-----------|-----------|
| **Free** | $0 | 5GB | 2GB | 0 | 1 user |
| **Pro** | $9/month | 50GB | 5GB | 500/month | 3 users |
| **Business** | $19/month | 200GB | 20GB | 2,000/month | 10 users |
| **Team** | $49/month | 1TB | 50GB | Unlimited | 25 users |
| **Enterprise** | Custom | Unlimited | Custom | Unlimited | Unlimited |

See [PRICING_ANALYSIS.md](./PRICING_ANALYSIS.md) for detailed pricing strategy.

---

## 🔒 Security

### Security Features

- **Password Hashing** - Bcrypt for secure password storage
- **CORS Protection** - Configurable origin restrictions
- **Rate Limiting** - Protection against abuse
- **Input Validation** - Ecto changesets for data validation
- **SQL Injection Protection** - Ecto parameterized queries
- **XSS Protection** - Phoenix auto-escaping

### Security Checklist

See [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) for complete security checklist.

---

## 📈 Roadmap

### Q1 2026
- Chunked upload system
- WebSocket progress tracking
- S3 storage integration

### Q2 2026
- Share link generation
- REST API completion
- React frontend

### Q3 2026
- Payment integration
- Zapier/Make.com integrations
- Admin dashboard

### Q4 2026
- Mobile apps
- Advanced analytics
- Enterprise features

---

## 🐛 Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL is running
pg_isready

# Verify database exists
psql -l | grep filetransfer

# Reset database
mix ecto.reset
```

### Port Already in Use

```bash
# Find process using port 4000
lsof -i :4000

# Kill process
kill -9 <PID>
```

### Dependency Issues

```bash
# Clean and reinstall
mix deps.clean --all
mix deps.get
mix deps.compile
```

### CORS Errors

- Verify `ALLOWED_ORIGINS` environment variable is set
- Check CORS plug is in API pipeline
- Verify origin matches exactly (including protocol)

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 👥 Team

- **Developer** - [@kojjob](https://github.com/kojjob)

---

## 🙏 Acknowledgments

- [Phoenix Framework](https://www.phoenixframework.org/) - Amazing web framework
- [Elixir](https://elixir-lang.org/) - Beautiful, functional language
- [Ecto](https://hexdocs.pm/ecto/) - Database wrapper
- All open-source contributors

---

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/kojjob/filetransfere_app/issues)
- **Email**: (Add your support email)
- **Documentation**: See [Documentation](#-documentation) section

---

## 🌟 Star History

If you find this project useful, please consider giving it a star ⭐!

---

**Built with ❤️ using Elixir and Phoenix**

