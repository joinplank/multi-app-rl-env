# Multi-App RL Environment

A comprehensive Reinforcement Learning gym environment that includes a complete CI/CD pipeline, monitoring stack, and a sample application with built-in performance testing capabilities.

## 🏗️ Architecture Overview

This environment provides:

- **Git Repository Management**: Gitea server with integrated CI/CD
- **Monitoring Stack**: Prometheus metrics collection + Grafana dashboards  
- **Sample RL Application**: Node.js/TypeScript app with intentional performance issues
- **CI/CD Pipeline**: Automated builds and deployments using Gitea Actions
- **Database Layer**: MySQL for data persistence, Redis for caching

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- curl (for API calls)
- git

### Setup Instructions

1. **Clone the repository** (if not already done):
   ```bash
   git clone <your-repo-url>
   cd multi-app-rl-env
   ```

2. **Run the setup script**:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```

   The setup script will:
   - Build and start all Docker containers
   - Initialize a MySQL database with sample data
   - Set up Gitea with a sample repository
   - Configure the CI/CD runner
   - Deploy the sample RL application
   - Configure monitoring dashboards

3. **Wait for the setup to complete**. The script provides colored output indicating progress.

## 🐳 Docker Services Created

The `docker-compose.yml` creates the following services:

| Service | Port | Purpose | Container Name |
|---------|------|---------|----------------|
| **Grafana** | 3001 | Monitoring dashboards | grafana |
| **Gitea** | 3002 | Git repository server | gitea |
| **Prometheus** | 9090 | Metrics collection | prometheus |
| **MySQL** | 3306 | Database | gitea-mysql |
| **Redis** | 6379 | Caching layer | gitea-redis |
| **Act Runner** | - | CI/CD executor | gitea-runner |
| **Sample App** | 3000 | RL gym application | rl-gym-app |

## 🎯 Service Access & Credentials

### Grafana (Monitoring Dashboard)
- **URL**: http://localhost:3001
- **Username**: `admin`
- **Password**: `admin123`
- **Direct Dashboard**: http://localhost:3001/d/rl-gym-performance/rl-gym-app-performance

### Gitea (Git Repository)
- **URL**: http://localhost:3002
- **Username**: `gitea_admin`
- **Password**: `gitea_admin_password`
- **Sample Repository**: http://localhost:3002/gitea_admin/rl-gym-use-case2

### Sample RL Application
- **Health Check**: http://localhost:3000/health
- **API Endpoints**: Various data processing endpoints available

### Prometheus (Metrics)
- **URL**: http://localhost:9090
- **Metrics Explorer**: http://localhost:9090/graph

## 🔧 High CPU Bug Fix Workflow

This environment includes a deliberate high CPU usage bug in the sample application to demonstrate performance monitoring and fixing workflows.

### Step 1: Observe High CPU Usage

1. **Access Grafana Dashboard**: 
   - Go to http://localhost:3001/d/rl-gym-performance/rl-gym-app-performance
   - Monitor the CPU usage metrics - you should see high CPU consumption

2. **Identify the Issue**: The `dataProcessingJob.ts` contains intensive mathematical operations that consume CPU unnecessarily.

### Step 2: Clone Repository and Apply Fix

1. **Clone the repository**:
   ```bash
   git clone http://gitea_admin:gitea_admin_password@localhost:3002/gitea_admin/rl-gym-use-case2.git
   cd rl-gym-use-case2
   ```

2. **Apply the high CPU fix**:
   ```bash
   ./fix_high_cpu.sh
   ```
   
   This script will:
   - Create a new feature branch
   - Apply the performance patch
   - Commit the changes
   - Push to the repository

### Step 3: Monitor CI/CD Pipeline

1. **Watch the pipeline**: 
   - Visit http://localhost:3002/gitea_admin/rl-gym-use-case2/actions
   - The CI/CD pipeline will automatically build and deploy the fix

2. **Verify deployment**: 
   - Check http://localhost:3000/health to ensure the app is running

### Step 4: Observe Performance Improvement

1. **Return to Grafana**: 
   - Monitor http://localhost:3001/d/rl-gym-performance/rl-gym-app-performance
   - You should see CPU usage drop significantly after the fix is deployed
   - Response times should improve

## 🏋️ Gym Environment Features

### Built-in CI/CD Pipeline

- **Automated Builds**: Every code push triggers a build pipeline
- **Docker Integration**: Applications are automatically containerized
- **Health Monitoring**: Built-in health checks and monitoring
- **Branch-based Workflows**: Support for feature branches and pull requests

### App Runner Capabilities

The environment includes a sophisticated app runner that:

- **Containerized Execution**: Runs applications in isolated Docker containers
- **Resource Monitoring**: Tracks CPU, memory, and network usage
- **Auto-scaling Support**: Can handle multiple application instances
- **Hot Reloading**: Supports live code updates during development

### Performance Testing Integration

- **Synthetic Workloads**: Built-in data processing jobs for testing
- **Metrics Collection**: Comprehensive performance metrics
- **Load Testing**: Configurable intensity levels for stress testing
- **Real-time Monitoring**: Live performance dashboards

## 📊 Monitoring & Observability

### Available Metrics

- **Application Performance**: Response times, throughput, error rates
- **System Resources**: CPU usage, memory consumption, disk I/O
- **Database Performance**: Query times, connection pools
- **CI/CD Metrics**: Build times, success rates, deployment frequency

### Custom Dashboards

The Grafana setup includes pre-configured dashboards for:

- **RL Gym App Performance**: Application-specific metrics
- **Infrastructure Overview**: System-level monitoring
- **CI/CD Pipeline Metrics**: Build and deployment tracking

## 🛠️ Development Workflow

1. **Code Changes**: Make changes to the application code
2. **Push to Repository**: Commit and push to trigger CI/CD
3. **Monitor Pipeline**: Watch the build and deployment process
4. **Observe Metrics**: Check performance impact in Grafana
5. **Iterate**: Repeat the cycle for continuous improvement

## 🔍 Troubleshooting

### Services Not Starting
- Check Docker containers: `docker compose ps`
- View logs: `docker compose logs <service-name>`
- Restart services: `docker compose restart`

### Performance Issues
- Check resource usage: `docker stats`
- Monitor application logs: `docker logs rl-gym-app`
- Review Grafana dashboards for bottlenecks

### CI/CD Pipeline Failures
- Check runner logs: `docker logs gitea-runner`
- Review pipeline configuration in `.github/workflows/`
- Verify repository permissions in Gitea

## 📚 Additional Resources

- **Gitea Documentation**: https://docs.gitea.io/
- **Grafana Dashboards**: https://grafana.com/docs/
- **Prometheus Metrics**: https://prometheus.io/docs/
- **Docker Compose**: https://docs.docker.com/compose/
