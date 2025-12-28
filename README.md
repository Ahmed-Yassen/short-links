# 🔗 ShortLink API

![Ruby](https://img.shields.io/badge/Ruby-3.2-red)
![Rails](https://img.shields.io/badge/Rails-8.0-red)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue)
![Redis](https://img.shields.io/badge/Redis-7-red)
![Docker](https://img.shields.io/badge/Docker-Ready-2496ED)
![Coverage](https://img.shields.io/badge/Tests-100%25-green)

> A containerized URL shortener API designed for **high concurrency**, **security**, and **scale**.

---

## 📖 Overview

ShortLink is an architectural demonstration of building a robust system that handles the "Hard Problems" of backend engineering: **The collision problem**, **Race Conditions**, **Idempotency**, and **Caching**.

### Key Features
* **🚀 Bijective Encoding:** Mathematically guaranteed unique short codes (Base62).
* **🛡️ Security First:** Rate limiting, recursive link prevention, and host authorization.
* **⚡ High Performance:** Redis Layer-1 caching for sub-millisecond reads.
* **🐳 Docker Native:** Zero-dependency setup with Docker Compose.
* **📜 OpenAPI Docs:** Interactive Swagger UI for testing endpoints.

---

## 🌍 Production Access & Behavior

### 🔗 Live URL
The application is deployed on Render. You can access the API documentation and endpoints here:

> **[https://short-link-app-160f.onrender.com/api-docs](https://short-link-app-160f.onrender.com/api-docs)**

---

### 💤 "Cold Start" (Sleep Mode)
This application runs on **Render's Free Tier**. To save resources, Render automatically spins down the web service after 15 minutes of inactivity.

#### What to expect:
1.  **The Delay:** If you are the first person to visit the site in a while, the request may hang for **50-60 seconds**.
2.  **The Fix:** Do not close the tab. Wait for the loading to finish.
3.  **The Result:** Once the container wakes up, it will serve all subsequent requests instantly (sub-millisecond latency).

**Why does this happen?**
Render puts the container to "sleep" (scales to 0). When a new request arrives, it has to provision a server, download the Docker image, boot Rails, and reconnect to the database.

---

## ⚡ Run Locally

You do not need Ruby or Postgres installed. You only need **Docker** and **Docker Compose**.

### 1. Build & Run
1. Clone the repository
```bash
git clone https://github.com/Ahmed-Yassen/short-links.git
cd short-links
```
2. Create the env file. Copy the content of .env.example
```
cp .env.example .env
```
3. Fire up the containers
```
docker compose up --build -d
```
### 2. Initialize Database
The entrypoint script handles migrations automatically on boot, but for the first run, ensure the DB is created:
```
docker compose exec web bin/rails db:create db:migrate
```

### 3. Verify Installation
Visit the interactive API Documentation (Swagger): http://localhost:3000/api-docs

---

## 🧪 Testing Guide

We use **RSpec** for comprehensive testing, covering Unit, Integration, and API specs.

### Running Tests
To run the full suite inside the Docker container:

```bash
docker compose exec -e RAILS_ENV=test web rspec
```
#### What is Tested
* **Concurrency** : Spawn multiple threads trying to shorten the exact same URL simultaneously to ensure Race Conditions are handled (only 1 DB record created).
* **Idempotency** : Ensure that re-submitting an existing URL returns the same short code, rather than creating a duplicate.
* **Validation** : Test against malformed URLs, recursive links, and empty bodies.
* **Security** : Verify that Rack::Attack correctly throttles requests after the limit is reached.
---

## 🏗 System Architecture

### 1. The Core Algorithm: Bijective Base62
We avoid random string generation (and the associated database lookups/collisions) by using a mathematical base conversion approach.

1.  **Sequence ID:** PostgreSQL generates a unique 64-bit integer (e.g., `1,000,001`).
2.  **Base62 Conversion:** We map that integer to a Base62 string (`0-9`, `a-z`, `A-Z`).
    * *Result:* ID `1,000,001` ➔ Short Code `LFL`.

#### Why Base62?
Base10 uses 10 digits. Base62 uses 62 characters. This density allows us to represent massive numbers in tiny strings.
* **6 chars** = ~56 Billion links.
* **7 chars** = ~3.5 Trillion links.



### 2. The "Security Twist" (Shuffled Alphabet)
Standard Base62 is predictable (`1`->`a`, `2`->`b`). To prevent users from guessing sequential links (Enumeration Attack), we **shuffle the alphabet**.

* **Standard Alphabet:** `0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ`
* **Our Alphabet:** `w9zP2...` (Configurable via ENV)
* **Outcome:** Sequential IDs generate completely uncorrelated strings, acting as a pseudo-encryption.

### 3. Trade-offs & Constraints
* **ID Gaps:** Relies on `nextval`. If a transaction rolls back, that ID is "burned".
    * *Verdict:* Acceptable impact. Missing a few IDs in a space of millions is irrelevant.
* **Database Coupling:** The architecture currently relies on a centralized SQL sequence.
    * *Verdict:* Optimal for current scale. Migration path to Snowflake IDs is available if needed.
---

## 🔒 Security Analysis

Here is how i mitigate specific attack vectors:

| Attack Vector | Risk | Mitigation Strategy |
| :--- | :--- | :--- |
| **Brute Force / Enumeration** | High | **Shuffled Alphabet** prevents predicting the next ID based on the previous one. **Rack::Attack** bans IPs exceeding request limits. |
| **Denial of Service (DoS)** | High | **Rate Limiting:** 60 req/min per IP. **Redis Cache:** Hot links are served from memory, protecting the DB from read-spikes. |
| **Recursive Loops** | Medium | Validator rejects URLs that point to the application's own host domain (e.g., trying to shorten a short link). |
| **Host Header Injection** | Medium | `HostAuthorization` middleware strictly whitelists allowed domains in Production environment. |
---
## 📈 Scalability Strategy

How do we go from 10k to 100M links?

### 1. The Collision Problem
**Current State:** Collisions are impossible. The Database Primary Key enforces uniqueness on a single node.

**Future Scale (Sharding):**
If we exceed the write capacity of a single Postgres node, we cannot rely on a single `AUTO_INCREMENT`.
* **Solution:** **High-Low ID Generation** or **IDs Range Allocator**.
* **Implementation:** Assign each shard a unique `Node_ID`. Prepend this to the sequence.
    * Shard 1 generates IDs starting with `1...`
    * Shard 2 generates IDs starting with `2...`
    * This ensures global uniqueness without cross-database coordination.

### 2. Read Scalability
**Current State:** Redis acts as a Layer-1 cache.

**Future Scale:**
* **Read Replicas:** Send `GET /decode` requests to Postgres Read Replicas to offload the master DB.
---
## ⚙️ Configuration & Operations

Behavior is controlled via Environment Variables (`.env`).

| Variable | Description | Default |
| :--- | :--- | :--- |
| `BASE62_ALPHABET` | The shuffled character set used for encoding. | (Standard Base62) |
| `REDIS_URL` | Connection string for Rate Limiting & Caching. | `redis://localhost:6379/1` |
| `DB_HOST` | Database Hostname. | `localhost` |
| `APP_HOST` | The domain of the app (used for validation). | `localhost` |

## ⚠️ Key Rotation Warning
The `BASE62_ALPHABET` acts as the encryption key for the short codes.

**If you change this variable, all previously generated short links will break** (they will decode to the wrong ID).

**Production Advice:**
Treat this key as permanent. If you must rotate it, you need to clean the database records following this strategy:
1.  Create a background-job or schedule a temporary maintainance shutdown.
1.  Decode old rows with the **Old Key**.
2.  Generate the new slug with the **New Key**.
3.  Update each record with the newly generated slug.
---
