*This project has been created as part of the 42 curriculum by aysadeq*

## Description
Inception is a System Administration and DevOps project that introduces Docker and Docker Compose. The objective is to build a robust, secure, and fully automated microservice infrastructure running inside a Virtual Machine. 

The architecture consists of three distinct containers communicating over an internal Docker network:
- **NGINX**: A web server strictly configured to accept only secure TLSv1.2/1.3 connections on port 443.
- **WordPress**: A dynamic CMS running on PHP-FPM, automatically configured using WP-CLI.
- **MariaDB**: A relational database that securely handles initialization and user grants through Docker Secrets.

All containers are built from the penultimate stable version of Debian (Bookworm) and run their core daemons flawlessly in the foreground as PID 1, completely avoiding prohibited background hacks like `tail -f` or `sleep infinity`. Persistent data is stored physically on the host machine using localized Docker Volumes.

## Design Choices & Technical Comparisons
To fulfill the infrastructure requirements, several specific architectural choices were made. Below is a comparison of the theoretical concepts involved:

### Virtual Machines vs Docker
- **Virtual Machines (VMs)**: Emulate an entire hardware stack, including a full guest Operating System (OS). They are heavy, slow to boot, and consume significant RAM/CPU.
- **Docker**: A containerization engine that isolates applications at the process level. It shares the host's OS kernel, making containers extremely lightweight, fast to boot, and highly efficient compared to VMs.

### Secrets vs Environment Variables
- **Environment Variables**: Can be easily exposed in logs, process trees (e.g., via `ps aux`), or Docker inspect commands. They are inherently insecure for sensitive data.
- **Docker Secrets**: Mount sensitive data (like passwords) securely into the container as temporary, in-memory files (typically in `/run/secrets/`). They are never exposed in environment variables or configuration logs, ensuring maximum security for database passwords.

### Docker Network vs Host Network
- **Host Network**: Binds the container directly to the host machine's network interface. It eliminates isolation, meaning container ports are exposed globally on the host.
- **Docker Network (Bridge)**: Creates an isolated, internal Virtual Local Area Network (VLAN) for containers. Containers can communicate securely using DNS names (e.g., `mariadb`), and ports are only exposed to the host if explicitly mapped (e.g., `443:443`). Our project uses a custom bridge network named `inception`.

### Docker Volumes vs Bind Mounts
- **Bind Mounts**: Maps a specific file or directory from the host directly into the container. It relies heavily on the host's exact file system structure and permissions.
- **Docker Volumes**: Fully managed by Docker and stored in Docker's internal directories (usually `/var/lib/docker/volumes/`). They are safer, easier to back up, and abstract away the host OS file system details. *Note: In this project, we explicitly configure local volumes to map to a specific physical location (`/home/aysadeq/data/`) to satisfy the subject's persistence requirements.*

## Instructions
### Prerequisites
- Docker Engine and `docker-compose-v2` must be installed.
- The `make` utility must be available.
- Ensure your host machine resolves `aysadeq.42.fr` to `127.0.0.1` (e.g., via `/etc/hosts`).

### Execution
1. Clone the repository and navigate to the root directory.
2. Run `make` to construct the images, initialize the volumes, and launch the infrastructure in the background.
3. Access the deployed website via `https://aysadeq.42.fr` (accept the self-signed TLS warning).
4. Access the administrator dashboard at `https://aysadeq.42.fr/wp-admin` using the credentials defined in the secrets directory.

### Management
- `make down`: Gracefully stops the containers without destroying data.
- `make clean`: Stops containers and removes the Docker volumes (data on the host hard drive is preserved).
- `make fclean`: The nuclear option. Completely wipes all containers, destroys all built images, and forcefully deletes all physical persistent data from the host machine to provide a 100% clean slate.

## Resources
During the development of this project, the following resources were utilized:
- **Docker Documentation**: Used extensively to understand Volume binding behaviors, internal Bridge networks, and the proper implementation of Docker Secrets.
- **NGINX Documentation**: Consulted for generating self-signed certificates and enforcing strict TLSv1.2/1.3 protocols.
- **MariaDB / WP-CLI Docs**: Used to automate database initialization and WordPress installation without manual intervention.

### AI Usage
AI was used as a learning tool to understand theoretical concepts and big new topics and tools.