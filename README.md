# Sivium Scripts

## Table of Contents
- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [Dependency Checker](#dependency-checker)
  - [Installer](#installer)
  - [Sentry Release Creator](#sentry-release-creator)
  - [Nginx and SSL Configuration](#nginx-and-ssl-configuration)
- [Scripts Overview](#scripts-overview)
- [Environment Variables](#environment-variables)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

**Sivium Scripts** is a collection of Bash scripts designed to streamline the setup, deployment, and maintenance of your Node.js projects. These scripts handle tasks such as dependency checks, environment configuration, automated Sentry releases, and Nginx SSL setup with Cloudflare integration. By automating these essential tasks, Sivium Scripts ensures a consistent and efficient workflow for developers and DevOps teams.

---

## Features

- **Dependency Management**: Automatically checks and verifies essential tools and scripts required for your project.
- **Automated Installation**: Downloads and configures necessary scripts, sets permissions, and initializes your environment.
- **Sentry Integration**: Automates the creation and management of Sentry releases based on your project's version.
- **Nginx & SSL Setup**: Configures Nginx with SSL certificates managed by `acme.sh`, integrates with Cloudflare for DNS management, and handles container registration with external services.
- **Flexible Configuration**: Supports various project types (backend, frontend, API, microservice) and package managers (bun, pnpm, yarn, npm).
- **Silent Mode**: Allows for non-interactive runs, suitable for CI/CD pipelines.

---

## Prerequisites

Before using Sivium Scripts, ensure that your system meets the following requirements:

- **Operating System**: Linux (tested on Ubuntu 20.04 and later)
- **Shell**: Bash
- **Essential Tools**:
  - [Wrangler](https://developers.cloudflare.com/workers/wrangler/)
  - [jq](https://stedolan.github.io/jq/)
  - [acme.sh](https://github.com/acmesh-official/acme.sh)
  - [PM2](https://pm2.keymetrics.io/)
  - [Bun](https://bun.sh/)
  - [sentry-cli](https://docs.sentry.io/product/cli/installation/)

Ensure these tools are installed and accessible in your system's `PATH`.

---

## Installation

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/SiviumSolutions/sivium-scripts.git
   cd sivium-scripts
   ```

2. **Make Scripts Executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Run the Dependency Checker**:
   ```bash
   ./dependency-checker.sh
   ```
   For silent mode:
   ```bash
   ./dependency-checker.sh --silent
   ```

---

## Configuration

1. **Create a `.env` File**:
   ```bash
   touch .env
   ```

2. **Populate `.env` with Required Variables**:
   ```env
   # Server Configuration
   PORT=3000
   CLUSTER_PORT=3001
   AUTO_UPDATE=1
   BRANCH=main
   PRJ_TYPE=frontend
   PKG_MANAGER=yarn
   BUILD_BEFORE_START=1
   REINSTALL_MODULES=0
   FORCE_REBUILD=0

   # Sentry Configuration
   SENTRY_AUTH_TOKEN=your_sentry_auth_token
   SENTRY_ORG=your_sentry_organization
   SENTRY_PROJECT=your_sentry_project

   # Nginx & SSL Configuration
   CF_Token=your_cloudflare_token
   CF_Account_ID=your_cloudflare_account_id
   CF_Zone_ID=your_cloudflare_zone_id
   EMAIL=your_email@example.com
   DOMAIN_NAME=yourdomain.com
   HOSTNAME=yourhostname
   SERVER_PORT=443
   CLUSTER_CLOUD_REGISTER_TOKEN=your_cluster_cloud_register_token
   CLUSTER_CLOUD_TOKEN=your_cluster_cloud_token
   ```

---

## Usage

### Dependency Checker

- **Purpose**: Verifies the installation of essential tools and scripts required for the project.
- **Command**:
  ```bash
  ./dependency-checker.sh [--silent]
  ```
- **Options**:
  - `--silent`: Runs the script without interactive prompts, suitable for automated environments.

---

### Installer

- **Purpose**: Downloads additional scripts, sets executable permissions, loads environment variables, and starts the main application.
- **Command**:
  ```bash
  ./installer.sh [--withUpdate]
  ```
- **Options**:
  - `--withUpdate`: Downloads and updates additional scripts (`sentry.sh`, `start.sh`, `check.sh`, `nginx.sh`).
- **Example**:
  ```bash
  ./installer.sh --withUpdate
  ```

---

### Sentry Release Creator

- **Purpose**: Automates the creation of a new release in Sentry based on the version specified in `package.json`.
- **Command**:
  ```bash
  ./sentry.sh
  ```
- **Steps**:
  1. Retrieves the version from `package.json`.
  2. Checks if a Sentry release with that version already exists.
  3. If not, creates and finalizes a new release.

---

### Nginx and SSL Configuration

- **Purpose**: Automates the setup and configuration of Nginx with SSL certificates managed by `acme.sh` and integrates with Cloudflare for DNS management.
- **Command**:
  ```bash
  ./nginx.sh [options]
  ```
- **Options**:
  - `--help, -h`: Display help message.
  - `--register, -r`: Register the container with the external service.
  - `--verify, -v`: Verify the container registration status.
  - `--force-renew, -f`: Force renewal of SSL certificates.
- **Examples**:
  - Register Container:
    ```bash
    ./nginx.sh --register
    ```
  - Verify Container Registration:
    ```bash
    ./nginx.sh --verify
    ```
  - Force Renew SSL Certificates:
    ```bash
    ./nginx.sh --force-renew
    ```

---

## Scripts Overview

1. **Dependency Checker (`dependency-checker.sh`)**:
   - Ensures all required commands and scripts are installed and executable.

2. **Installer (`installer.sh`)**:
   - Manages the installation and setup of additional scripts and environment configurations.

3. **Sentry Release Creator (`sentry.sh`)**:
   - Automates the creation and management of Sentry releases.

4. **Nginx and SSL Configuration (`nginx.sh`)**:
   - Sets up Nginx with SSL, integrates with Cloudflare, and manages container registration.

---

## Environment Variables

Refer to the example `.env` file [here](#configuration).

---

## Contributing

Contributions are welcome! To contribute:

1. **Fork the Repository**:  
   [Fork on GitHub](https://github.com/SiviumSolutions/sivium-scripts/fork)

2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/YourFeatureName
   ```

3. **Commit Your Changes**:
   ```bash
   git commit -m "Add some feature"
   ```

4. **Push to the Branch**:
   ```bash
   git push origin feature/YourFeatureName
   ```

5. **Open a Pull Request**:  
   [Create Pull Request](https://github.com/SiviumSolutions/sivium-scripts/compare)

---

## License

This project is licensed under the [MIT License](LICENSE). See the `LICENSE` file for details.

---

© 2024 Sivium Solutions. All rights reserved.  
For inquiries or support, contact: [support@sivium.solutions](mailto:support@sivium.solutions)
