# Inception Learning Guide

This guide is designed to take you from foundational operating system concepts all the way to understanding the complex interactions of a multi-container web architecture. It is broken down into four modules, ensuring every major concept is explained in detail.

---

## Module 1: Linux & Operating System Fundamentals
*Understanding the Linux operating system is the key to truly grasping how containers work under the hood. Containers are not magic; they are just isolated Linux processes.*

### 1. Processes and Lifecycles
*   **What is a Process?** An executing instance of a program. Every running application is at least one process, managed by the Linux kernel.
*   **The Process Tree and PID 1:** Every process is assigned a Process ID (PID). When a Linux system boots, the kernel starts the first process, assigned **PID 1** (usually `systemd` or `init`). Every other process is a "child" created by this init process, forming a tree structure. PID 1 has special responsibilities, like adopting orphaned child processes.
*   **Process States and Signals:** Processes can be running, sleeping, or stopped. The OS communicates with processes using signals (e.g., `SIGTERM` asks a process to terminate gracefully; `SIGKILL` forces it to terminate immediately).
*   **Zombies and Orphans:** If a child process finishes but its parent doesn't acknowledge its death, it becomes a "zombie." If a parent dies before its child, the child becomes an "orphan" and is adopted by PID 1, which must properly clean it up.

### 2. Namespaces
*   **What is a Namespace?** A Linux kernel feature that provides isolation. It makes a process believe it has its own isolated instance of a global resource. This is the core technology behind containers.
*   **Types of Namespaces:**
    *   **PID Namespace:** Provides a separate process tree. A process inside the container can be PID 1, even if it's actually PID 4521 on the host machine.
    *   **NET Namespace:** Provides isolated network interfaces, IP addresses, and routing tables.
    *   **MNT Namespace:** Provides an isolated file system view (mount points).
    *   **UTS Namespace:** Allows the container to have its own hostname.
    *   **USER Namespace:** Maps user and group IDs, allowing a process to be root inside the container but an unprivileged user outside.
    *   **IPC Namespace:** Isolates inter-process communication resources.

### 3. Control Groups (Cgroups)
*   **What are Cgroups?** While Namespaces isolate what a process can *see*, Cgroups limit what a process can *use*.
*   **Resource Limiting:** Cgroups allow the kernel to restrict the amount of CPU, RAM, Disk I/O, and Network bandwidth a group of processes can consume.
*   **Preventing Host Takeover:** By using Cgroups, you ensure that if one container goes crazy (e.g., a memory leak), it will be killed by the kernel before it crashes the entire host machine.

### 4. Union File Systems (OverlayFS)
*   **What is a Union File System?** A file system that works by layering multiple directories (called "branches") on top of each other to present a single, unified view to the user. The most common implementation in modern Docker is **OverlayFS**.
*   **Layers:** Each layer is read-only and contains only the changes (diffs) from the layer below it. For example, Layer 1 might be a base Debian file system, Layer 2 adds Nginx, and Layer 3 adds your configuration file.
*   **Copy-on-Write (CoW):** When a running container needs to modify a file that exists in a read-only layer, the file system copies that file up to the thin, writable layer on top. The original read-only layer remains untouched. This is what makes containers lightweight and fast to create.
*   **Why it matters:** If you run 10 containers from the same image, they all share the exact same read-only base layers on disk. Each container only needs its own tiny writable layer for its runtime changes.

---

## Module 2: The Virtualization Layer
*Building on Linux fundamentals, this module explores how Docker leverages Namespaces, Cgroups, and UnionFS to create lightweight containers.*

### 1. Virtual Machines vs. Containers
*   **Hardware Virtualization (VMs):** A hypervisor (like VirtualBox or VMware) emulates physical hardware. You install a full, heavy "Guest OS" on top of that virtual hardware.
*   **OS-Level Virtualization (Containers):** Containers share the host machine's Linux kernel. They only package the application and its dependencies (libraries/binaries), making them extremely fast to start and lightweight in terms of memory.

### 2. What is Docker?
*   **Docker Daemon (`dockerd`):** The background service running on the host that actually builds, runs, and manages containers by interacting directly with the Linux kernel.
*   **Images vs. Containers:**
    *   **Image:** A read-only template (a snapshot) containing the application code, libraries, tools, and dependencies. It is built from layered UnionFS layers. It is static.
    *   **Container:** A running, isolated instance created from an Image. It adds a thin writable layer on top and is wrapped in Namespaces and Cgroups. It is dynamic.

### 3. The Dockerfile
*   **What is it?** A text script containing the sequential instructions used to assemble a Docker image. Each instruction creates a new read-only layer in the Union File System.
*   **Key Instructions:**
    *   `FROM`: Defines the base image (e.g., `alpine` or `debian`). This is the bottom layer.
    *   `RUN`: Executes commands inside the image during the build process (e.g., `apt-get install nginx`). Each `RUN` creates a new layer.
    *   `COPY`: Copies files from your host machine into the image.
    *   `EXPOSE`: Documents which port the container listens on. It does NOT publish the port; it is metadata for other developers.
    *   `CMD` / `ENTRYPOINT`: Defines the default command that executes when a container starts.
*   **Shell Form vs. Exec Form:** This is critical for the PID 1 problem.
    *   **Exec Form** `CMD ["nginx", "-g", "daemon off;"]` — The command runs directly as PID 1. It receives signals (like `SIGTERM` from `docker stop`) properly. **Always use this.**
    *   **Shell Form** `CMD nginx -g "daemon off;"` — The kernel actually runs `/bin/sh -c nginx ...`. This means `/bin/sh` becomes PID 1, and your application runs as a child process. Signals are sent to the shell, not your app, so `docker stop` won't shut down gracefully.
*   **The `latest` Tag is Forbidden:** When you write `FROM debian`, Docker implicitly pulls `debian:latest`. The `latest` tag is a moving target — it changes every time Debian releases an update. This makes your builds non-reproducible. The Inception subject explicitly forbids it. Always pin a specific version: `FROM debian:bullseye`.
*   **Best Practices:** Ordering instructions efficiently to maximize Docker's layer caching, combining multiple `RUN` commands with `&&` to reduce layer count, and cleaning up temporary files in the same layer they were created.

### 4. Build Context & `.dockerignore`
*   **Build Context:** When you run `docker build`, Docker sends the entire directory (the "build context") to the Docker Daemon. If your directory contains large files (like database dumps or logs), the build becomes slow.
*   **`.dockerignore`:** Works exactly like `.gitignore`. It tells Docker to exclude specific files and directories from the build context. The Inception subject requires a `.dockerignore` file for each service.

### 5. The PID 1 Problem in Containers
*   **The Container's Main Process:** When a container starts, the command specified in `CMD` or `ENTRYPOINT` becomes PID 1 inside that container's PID Namespace.
*   **Missing Init Systems:** Containers do not usually have `systemd` or `init`. If your application (now PID 1) does not know how to handle OS signals (`SIGTERM`) or reap zombie processes, it can cause shutdowns to hang or leak resources.
*   **The Danger of Hacky Patches:** Using `tail -f /dev/null`, `sleep infinity`, or infinite `while` loops as your main process means your actual application runs in the background. If the application crashes, the container stays alive doing nothing, defeating the purpose of containerization.
*   **The Solution:** Run your application in the **foreground** using Exec Form. For example, NGINX has a flag `daemon off;`, MariaDB can run via `mysqld_safe`, and PHP-FPM has a flag `--nodaemonize` (`-F`). These keep the process as PID 1 and handle signals correctly.

---

## Module 3: The Orchestration Layer
*Managing a single container is easy. Managing multiple containers that need to talk to each other and share data requires orchestration tools like Docker Compose.*

### 1. Docker Compose
*   **Declarative Infrastructure:** Instead of typing long `docker run` commands in the terminal, you write a `docker-compose.yml` file that declares what your entire infrastructure should look like.
*   **Services & Dependencies:** You define multiple "services" (e.g., database, web server). You can define dependencies (e.g., WordPress `depends_on` MariaDB), ensuring containers start in the correct order.
*   **Service Readiness vs. Start Order:** `depends_on` only guarantees the container has *started*, not that the service inside it is *ready* to accept connections. For example, MariaDB might take 5 seconds to initialize its database after the container starts. If WordPress tries to connect during those 5 seconds, it will crash. The solution is to use a **wait loop** in your entrypoint script that checks if MariaDB is accepting connections before proceeding.

### 2. Docker Networks
*   **Bridge Networks:** Docker creates virtual network switches. By creating a custom network in Docker Compose, all your containers are attached to it and can communicate securely.
*   **DNS Resolution:** You don't need to know the IP addresses of your containers. Docker provides an internal DNS server. The NGINX container can reach the WordPress container simply by using the service name `wordpress` as a hostname.
*   **Why `--link` and `host` network are Forbidden:** `--link` is a legacy mechanism that is static and fragile. `network: host` removes the NET Namespace entirely, meaning the container shares the host's network directly — this defeats the purpose of isolation. The project requires custom bridge networks.

### 3. Docker Volumes
*   **Ephemeral vs. Persistent Storage:** By default, data written inside a container is ephemeral; when the container is deleted, the data is gone forever.
*   **Named Volumes:** Docker manages a storage area on the host machine. You mount this volume into a container. If the container dies, the volume and its data persist.
*   **Bind Mounts:** You explicitly tell Docker to mount a specific folder on your host machine into the container. The Inception subject forbids bind mounts for the two main volumes.
*   **Volume Driver Options:** The Inception subject requires that named volumes store their data at `/home/login/data` on the host. To achieve this, you configure the volume in `docker-compose.yml` using driver options (`driver_opts`) with `type: none`, `o: bind`, and `device: /home/login/data/...`. This makes Docker treat a specific host directory as a named volume.

### 4. Environment Variables & Secrets
*   **Parameterizing Containers:** Images should be generic. You inject configuration (like a database password) into the container at runtime using environment variables.
*   **`.env` Files:** Docker Compose can read a `.env` file and automatically inject those variables into your containers.
*   **Docker Secrets:** A more secure mechanism than environment variables. Secrets are stored as files mounted into the container at `/run/secrets/<secret_name>`. The application reads the file to get the value. Unlike environment variables, secrets don't appear in `docker inspect` output or process listings, making them harder to leak accidentally. The Inception subject strongly recommends using secrets for all passwords and credentials.
*   **Security Rules:** Never hardcode passwords in a Dockerfile. Never commit `.env` files or secret files to Git. Any credentials found in the Git repository = automatic project failure.

### 5. Container Restart Policies
*   **Why?** The Inception subject states: *"Your containers have to restart in case of a crash."*
*   **`restart: always`** — The container will always restart, no matter what. Even after a reboot of the host machine.
*   **`restart: on-failure`** — The container only restarts if it exits with a non-zero (error) exit code. If it exits cleanly (exit code 0), it stays stopped.
*   **`restart: unless-stopped`** — Like `always`, but if you manually stop the container with `docker stop`, it stays stopped even after a host reboot.

---

## Module 4: The Application Stack (LEMP)
*How the specific technologies requested by the Inception subject interact to serve a website.*

### 1. The LEMP Architecture Overview
*   **L**inux (The OS/Container base)
*   **E**Nginx (Web Server)
*   **M**ariaDB (Database)
*   **P**HP-FPM (Application Logic)
*   **Flow:** The user's browser requests `https://aysadeq.42.fr`. NGINX receives it. Since it's a dynamic request for WordPress, NGINX passes it to PHP-FPM via the FastCGI protocol. PHP-FPM executes the WordPress code, which queries MariaDB for data. The resulting HTML is sent back through NGINX to the user.

### 2. NGINX (The Web Server)
*   **Static vs. Dynamic Content:** NGINX is excellent at directly serving static files (images, CSS, HTML). It cannot execute PHP code by itself.
*   **Reverse Proxy:** When a user requests a PHP file, NGINX acts as a middleman, proxying the request to the PHP-FPM container on port `9000` using the `fastcgi_pass` directive.

### 3. TLS/SSL (HTTPS)
*   **What is TLS?** Transport Layer Security encrypts the communication between the user's browser and the server, preventing anyone from eavesdropping on the data.
*   **Certificates and Keys:** TLS requires two files: a **certificate** (the public identity card that tells the browser "I am aysadeq.42.fr") and a **private key** (the secret used to encrypt and decrypt traffic). They are generated together as a pair.
*   **Self-Signed vs. CA-Signed:** A Certificate Authority (CA) like Let's Encrypt signs certificates that browsers trust automatically. For this project, we generate **self-signed** certificates using `openssl`. The browser will show a warning because it doesn't trust our homemade certificate, but the encryption itself is identical.
*   **TLSv1.2 and TLSv1.3:** The Inception subject mandates these versions only. Older versions (TLSv1.0, TLSv1.1, SSLv3) have known security vulnerabilities and must be disabled in your NGINX configuration.
*   **Port 443:** NGINX must be the only entrypoint into the infrastructure, listening exclusively on port `443` (the standard HTTPS port).

### 4. MariaDB (The Database)
*   **Relational Databases:** Data is stored in structured tables (like spreadsheets) linked together by relationships.
*   **Storage Mechanisms:** The actual database files will be stored in our Docker Volume to ensure persistence.
*   **User Security:** We must configure a root password and create a dedicated, non-root user specifically for WordPress to use when connecting. The root account should not be accessible remotely.

### 5. PHP-FPM (FastCGI Process Manager)
*   **What is it?** A daemon that runs in the background waiting for PHP execution requests.
*   **How it works:** When NGINX forwards a request via the FastCGI protocol, PHP-FPM spins up a worker process to compile and execute the PHP scripts, then returns the raw HTML output to NGINX.
*   **Configuration:** PHP-FPM must be configured to listen on port `9000` (via a TCP socket) so that the NGINX container (on a separate network namespace) can reach it.

### 6. WordPress
*   **The CMS:** A robust Content Management System built on PHP.
*   **`wp-config.php`:** The critical configuration file where WordPress learns the hostname of the MariaDB container, the database name, and the user credentials required to connect. We will generate this file dynamically using our environment variables when the container starts.
*   **WP-CLI:** A command-line tool for managing WordPress without a browser. In our container's entrypoint script, we will use WP-CLI to download WordPress core files, create the `wp-config.php`, run the installation, and create the required users (including an admin user whose name must not contain "admin").
*   **Two Required Users:** The Inception subject requires at least two users in the WordPress database. One is an administrator (with a non-obvious username), and the other is a regular user/editor.

### 7. Domain Name Configuration
*   **The Requirement:** The Inception subject requires your domain `aysadeq.42.fr` to point to your local IP address.
*   **`/etc/hosts` File:** Instead of buying a real domain and configuring DNS servers, you edit the `/etc/hosts` file on the host machine to add a line like `127.0.0.1 aysadeq.42.fr`. This tells the operating system to resolve that domain locally without ever querying the internet.
*   **Why this works:** When the browser tries to load `https://aysadeq.42.fr`, the OS checks `/etc/hosts` first, finds the mapping to `127.0.0.1`, and sends the request to your own machine where Docker's port mapping forwards it into the NGINX container.
