# Quick Start: Deploying to Heroku

This guide will help you deploy your WebSocket relay server to Heroku so your itch.io game can connect to real players worldwide.

## Prerequisites

1. Heroku account (free): https://www.heroku.com/
2. Git installed on your machine
3. Heroku CLI installed: https://devcenter.heroku.com/articles/heroku-cli

## Step 1: Prepare Your Repository

The following files are already provided in this project:
- `relay-server.js` - The WebSocket relay server
- `package.json` - Node.js dependencies
- `Procfile` - Heroku configuration (create this if missing)

If you don't have a `Procfile`, create one in the root directory:

```
web: node relay-server.js
```

## Step 2: Initialize Git Repository (if not already done)

```bash
cd path/to/your/project
git init
git add .
git commit -m "Initial commit with relay server"
```

## Step 3: Create and Deploy to Heroku

### Option A: Using Heroku CLI (Recommended)

```bash
# Login to Heroku
heroku login

# Create a new Heroku app
heroku create your-app-name

# Deploy
git push heroku main
# (or 'master' if your branch is named master)

# View logs
heroku logs --tail
```

### Option B: Deploy via GitHub

1. Push code to GitHub
2. Go to https://dashboard.heroku.com/apps
3. Create new app → Connect to GitHub
4. Select your repository
5. Enable automatic deploys

## Step 4: Get Your WebSocket URL

After deployment, your WebSocket URL is:
```
wss://your-app-name.herokuapp.com
```

## Step 5: Update Godot Script

In [Scripts/menu_&_server.gd](Scripts/menu_&_server.gd), update:

```gdscript
@export var websocket_url = "wss://your-app-name.herokuapp.com"
```

## Step 6: Test the Server

```bash
# Check server status
curl https://your-app-name.herokuapp.com/health

# View server stats
curl https://your-app-name.herokuapp.com/stats
```

## Monitoring

### View Real-time Logs
```bash
heroku logs --tail --app your-app-name
```

### View Metrics
```bash
# Memory usage
heroku ps -a your-app-name

# Recent errors
heroku logs --app your-app-name | grep ERROR
```

## Scaling Up (Optional)

For better performance with more players:

```bash
# Scale to more dynos (costs money, starts at $7/month per additional dyno)
heroku ps:scale web=2 --app your-app-name
```

## Environment Variables (Optional)

To set environment variables on Heroku:

```bash
heroku config:set NODE_ENV=production --app your-app-name
```

## Troubleshooting

### Server won't start
```bash
heroku logs --tail --app your-app-name
```

### Port issues
- Heroku automatically assigns PORT via environment variable
- Our server uses: `process.env.PORT || 8080`

### WebSocket connection fails
- Use `wss://` (WebSocket Secure) instead of `ws://`
- Check that your Godot URL matches the Heroku app name

### Kill/Restart Server
```bash
heroku restart --app your-app-name
```

## Free Tier Limitations

Heroku's free tier has been discontinued, but low-cost options:
- **Heroku Pro**: $50/month (single dyno)
- **Railway.app**: Free tier available, better pricing
- **Render.com**: Free WebSocket support

## Alternative Hosting

If Heroku doesn't work for you:

### Railway.app (Recommended)
1. Go to https://railway.app/
2. Connect GitHub account
3. Select project with relay-server.js
4. Deploy

### Render.com
1. Go to https://render.com/
2. New Web Service
3. Connect GitHub
4. Use settings:
   - Build Command: `npm install`
   - Start Command: `npm start`

### AWS / DigitalOcean / Linode
- More complex setup but more control
- Better for high-traffic games

## Keeping Server Up

To prevent Heroku from sleeping your free app (if using alternative service):
- Add a monitoring service that pings your `/health` endpoint
- Services like Kuma Uptime Monitor (free) can do this

## Custom Domain (Optional)

To use a custom domain instead of `herokuapp.com`:

```bash
heroku domains:add yourdomain.com --app your-app-name
```

## Next Steps

1. ✅ Deploy relay server
2. ✅ Update Godot script with new WebSocket URL
3. ✅ Export HTML5 build
4. ✅ Upload to itch.io
5. ✅ Test with real players

Your multiplayer game should now work on itch.io!
