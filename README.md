# Kolide Quickstart Demo

The scripts and config files in this repository will enable you to quickly get a demo Kolide installation up and running. If you would like to try Kolide without setting up a production testing environment, this demo is for you. For guidance on installing a production Kolide environment, please see the [infrastructure documentation](https://docs.kolide.co/kolide/current/infrastructure/index.html).

The scripts in the demo assume you already have registered for Kolide. You can sign up for Kolide on our [website](https://kolide.co/).
We're also available to help with this script, or deploying Kolide in your environment.
You can contact us by email at support@kolide.co or by joining #kolide on the [osquery slack team](https://osquery-slack.herokuapp.com/).

If you would like to contribute to the script, you can open an [Issue](https://github.com/kolide/kolide-demo/issues) or [Pull Request](https://github.com/kolide/kolide-demo/pulls).

## Dependencies

-  Bash compatible shell with standard unix commands
-  [Docker](https://docs.docker.com/engine/installation/)

All other necessary dependencies will be installed via Docker by the scripts in this repository.

## Usage

### Start Kolide (and Dependencies)
```bash
git clone https://github.com/kolide/kolide-demo.git # or download and unzip https://github.com/kolide/kolide-demo/archive/master.zip
cd kolide-demo
./demo.sh up
```

On the first run, a self-signed TLS certificate will be generated to be used with your trial instance of Kolide. Please enter a CN for this certificate that osquery hosts will be able to use to connect.
If you already have a trusted TLS certificate, you can provide it in this step.
```
./demo.sh up /path/to/server.key /path/to/server.crt
```

When startup completes successfully, a message will be printed with a link to the Kolide instance. At this URL you will be walked through licensing and final setup.

### Stop Kolide (and Dependencies)

```bash
./demo.sh down
```

This will terminate the containers running Kolide and its dependencies, but data will persist across restarts. Use `./demo.sh up` to start again.

### Reset Kolide Instance

```bash
./demo.sh reset
```

This will terminate the containers, and remove the MySQL data and generated TLS certificate. Use `./demo.sh up` to start again from scratch.

## Enroll Endpoints

This Kolide demo comes with various methods for adding hosts. It can easily be tested with containerized fake hosts in Docker, but testing with real hosts will help you understand the true value Kolide can bring to your infrastructure.

### Retrieve Enroll Secret

Adding hosts requires retrieving the host enroll secret from the Kolide application. To do so, navigate to Hosts  (`/hosts/manage`) and click the "Add New Host" button in the upper-right corner. At the bottom of this dialog, you can reveal or copy the enroll secret. In the screenshot below, relevant sections of the UI are highlighted in red.

<img width="1348" alt="Retrieving enroll secret" src="https://cloud.githubusercontent.com/assets/575602/22949370/e56458e4-f2b6-11e6-8c0d-78d47548ce00.png">

### Add Docker-based Hosts

These Docker-based hosts can be added immediately with no additional setup. Because the containers are all built from the same image, they will return similar results for most queries. To enroll docker-based hosts:

```bash
./demo.sh add_hosts <number of hosts> <enroll secret>
```

Example:
```bash
./demo.sh add_hosts 10 u5M9Y4T7u78rNHPI+dwEDXAC7XqPcnfx
```

You can run the command multiple times to scale the number of enrolled osqueryd containers up or down.

### Add macOS Hosts

This demo can generate an installer (`.pkg`) that will configure a macOS osquery installation to work with the Kolide server. To build this package:

```bash
./demo.sh enroll mac <enroll secret>
```

Example:
```bash
./demo.sh enroll mac u5M9Y4T7u78rNHPI+dwEDXAC7XqPcnfx
```

The generated installer will be located in `out/kolide-enroll-1.0.0.pkg`.

Now, ensure that [osquery is installed](https://osquery.io/downloads/) on the target host, and run the generated installer package to configure the osquery installation.

Note: If you want to enroll the macOS host that this demo is running on you may have to edit the `/etc/hosts` file as specified in the output when generating the installer.

### Add Linux Hosts

Soon we will introduce package generation for configuring Linux osquery hosts to operate with this demo.

## Testing with Email (Optional)

Email setup is not required to demo Kolide. For those who would like to demo Kolide with a simulated email server, `./demo.sh up` starts a Mailhog container that facilitates this. In a production Kolide deployment, you would use your normal SMTP server.

### Set Up Email

To configure Kolide with this demo email server:

1. In Kolide, navigate to Admin -> App Settings (`/admin/settings`).
2. Make up a Sender Address (eg. `kolide@yourdomain.com`).
2. Enter SMTP server `mailhog` and port `1025`.
3. Set Authentication Type to `None`.
4. Click "Update Settings"

When completed, the configuration should look like this:

<img width="802" alt="Kolide Mailhog email configuration" src="https://cloud.githubusercontent.com/assets/575602/22914173/ff30949c-f223-11e6-8f3f-27675d6dbedb.png">

### Viewing Emails

Mailhog starts a UI available at port `8025` on your docker host ([http://localhost:8025](http://localhost:8025) if you are on the docker host) for viewing the emails "sent" through its SMTP server. If email is properly configured, you should see a test message from Kolide in this UI.
