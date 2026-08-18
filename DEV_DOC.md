# Developer Documentation

## 1. Setting up the Environment from Scratch
To configure this project on a fresh machine, ensure the following prerequisites and configurations are met:
- **Prerequisites**: A Linux environment (preferably Debian/Ubuntu) with Docker Engine, `docker-compose-v2`, and the `make` utility installed.
- **Host Configuration**: You must map the domain `aysadeq.42.fr` to `127.0.0.1` (usually achieved by modifying `/etc/hosts` or using a browser DNS override).
- **Secrets**: The infrastructure strictly requires Docker Secrets to boot. Create a `secrets/` directory at the root of the project and populate it with the following four files (containing raw passwords with no trailing newlines):
  - `db_password.txt`
  - `db_root_password.txt`
  - `wp_admin_password.txt`
  - `wp_user_password.txt`
- **Environment Variables**: An `.env` file must be present in the `srcs/` directory containing non-sensitive configuration keys (e.g., database names and user emails).

## 2. Building and Launching the Project
The entire build process is automated via the `Makefile` located at the root of the repository.
- To build the custom images from their respective Dockerfiles and launch the containers via Docker Compose, simply run:
  ```bash
  make
  ```
  This command will dynamically provision the data directories, build the internal `inception` bridge network, and start all containers in detached mode (`-d`).

## 3. Managing Containers and Volumes
Use the provided Makefile rules to gracefully manage the Docker Compose lifecycle:
- **`make down`**: Runs `docker compose down` to gracefully stop all running containers.
- **`make clean`**: Runs `docker compose down -v`. This stops the containers and removes the Docker Named Volumes. (Note: Because the volumes are bind-mounted to the host, this does *not* delete the physical data).
- **`make fclean`**: The total teardown command. It executes `clean`, runs `--rmi all` to destroy all built Docker images, and forcefully removes (`rm -rf`) all physical data directories from the host machine.
- **`make re`**: Executes `fclean` followed by `make` to provide a complete, clean rebuild.

## 4. Data Storage and Persistence
This project ensures strict data persistence that survives container termination and system reboots.
- **Storage Location**: The data is mapped directly to the host machine's physical hard drive. 
  - Database files are stored in `/home/aysadeq/data/mariadb/`.
  - WordPress core files and assets are stored in `/home/aysadeq/data/wordpress/`.
- **How it Persists**: We utilize Docker Local Volumes configured with `driver_opts` (specifically `type: none`, `o: bind`, `device: /path/`) in `docker-compose.yml`. This links the Docker volume directly to the host's physical directory, ensuring that even if the Docker volume is deleted, the physical data on the host remains intact until explicitly removed by the administrator.
