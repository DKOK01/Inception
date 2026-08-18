# User Documentation

## 1. Provided Services
This infrastructure provides a fully functional, self-hosted web stack:
- **Web Server**: NGINX securely serves the website over HTTPS (TLS encryption).
- **CMS (Content Management System)**: WordPress allows you to publish blog posts and manage a dynamic website.
- **Database**: MariaDB safely stores all users, posts, and configuration data for WordPress.

## 2. Starting and Stopping the Project
- **Start**: Run `make` in the root directory. This builds and launches all services in the background.
- **Stop**: Run `make down` to safely stop the containers.
- **Clean**: Run `make clean` to stop containers and remove Docker networks/volumes (preserves physical data).
- **Total Reset**: Run `make fclean` to wipe the infrastructure and permanently delete all physical data.

## 3. Accessing the Website and Administration Panel
- **Website**: Open a browser and navigate to `https://aysadeq.42.fr` (accept the self-signed TLS warning if prompted).
- **Admin Panel**: Navigate to `https://aysadeq.42.fr/wp-admin`. 

## 4. Locating and Managing Credentials
All sensitive credentials are required to be kept in secure text files before starting the stack. 
- **Location**: Store your credentials in the `secrets/` directory at the root of the project.
- **Files**:
  - `secrets/db_password.txt`: The database user's password.
  - `secrets/db_root_password.txt`: The root database password.
  - `secrets/wp_admin_password.txt`: The password for the WordPress administrator (`superchief`).
  - `secrets/wp_user_password.txt`: The password for the standard WordPress user (`editor42`).
*(Note: Do not include trailing spaces or newlines in these files).*

## 5. Checking that Services are Running Correctly
To verify the health of the infrastructure:
1. Open a terminal and run `docker ps`. You should see `mariadb`, `wordpress`, and `nginx` with a status of **Up**.
2. Visit the Admin Panel and log in. If the dashboard loads successfully, the web server, PHP processor, and database are perfectly linked.
3. Test functionality by adding a comment to the default blog post using the standard WordPress user.
