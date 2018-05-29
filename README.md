This repository was created to demo Kolide Fleet before it was available as an open source tool. Because Fleet is now open source, please refer to [the Fleet docs](https://github.com/kolide/fleet/tree/master/docs) for information on getting started with Fleet.

---

# Kolide Quickstart Demo

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy?template=https://github.com/kolide/kolide-quickstart/tree/master)

The scripts and config files in this repository will enable you to quickly get a demo Kolide Fleet installation up and running. If you would like to try Fleet without setting up a production testing environment, this demo is for you. For guidance on installing a production Fleet environment, please see the [infrastructure documentation](https://github.com/kolide/fleet/tree/master/docs/infrastructure).

We're available to help with this script, or deploying Kolide in your environment.
You can contact us by email at support@kolide.co or by joining #kolide on the [osquery slack team](https://osquery-slack.herokuapp.com/).

If you would like to contribute to the script, you can open an [Issue](https://github.com/kolide/kolide-quickstart/issues) or [Pull Request](https://github.com/kolide/kolide-quickstart/pulls).

## Dependencies

-  Bash compatible shell with standard unix commands
-  Git, or a way to download and unzip these scripts
-  [Docker](https://docs.docker.com/engine/installation/) and [Docker Compose](https://docs.docker.com/compose/install/) (installed by default with Docker on Mac and Windows)

All other necessary dependencies will be installed via Docker by the scripts in this repository.

## Quickest Setup

```bash
git clone https://github.com/kolide/kolide-quickstart.git
cd kolide-quickstart
./demo.sh up simple
./demo.sh add_hosts 10 # Will add 10 containerized hosts to your installation
```

At this point you can navigate to [https://localhost:8412](https://localhost:8412) (or the IP/DNS name of the server running Kolide) and log in with the credentials supplied in the output of the above script.

More advanced setup is explained below.

## Usage

### Start Fleet (and Dependencies)
```bash
git clone https://github.com/kolide/kolide-quickstart.git # or download and unzip https://github.com/kolide/kolide-quickstart/archive/master.zip
cd kolide-quickstart
./demo.sh up
```

On the first run, a self-signed TLS certificate will be generated to be used with your demo instance of Fleet. Please enter a CN for this certificate that osquery hosts will be able to use to connect.
If you already have a trusted TLS certificate, you can provide it in this step.
```
./demo.sh up /path/to/server.key /path/to/server.crt
```

When startup completes successfully, a message will be printed with a link to the Kolide instance. At this URL you will be walked through final setup.

### Stop Fleet (and Dependencies)

```bash
./demo.sh down
```

This will terminate the containers running Fleet and its dependencies, but data will persist across restarts. Use `./demo.sh up` to start again.

### Reset Fleet Instance

```bash
./demo.sh reset
```

This will terminate the containers, and remove the MySQL data and generated TLS certificate. Use `./demo.sh up` to start again from scratch.

## Enroll Endpoints

This Fleet demo comes with various methods for adding hosts. It can easily be tested with containerized fake hosts in Docker, but testing with real hosts will help you understand the true value Fleet can bring to your infrastructure.

### Add Docker-based Hosts

These Docker-based hosts can be added immediately with no additional setup. Because the containers are all built from the same image, they will return similar results for most queries. To enroll docker-based hosts:

```bash
./demo.sh add_hosts <number of hosts>
```

You can run the command multiple times to scale the number of enrolled osqueryd containers up or down.

### Add macOS Hosts

This demo can generate an installer (`.pkg`) that will configure a macOS osquery installation to work with the Fleet server. To build this package:

```bash
./demo.sh enroll mac
```

The generated installer will be located in `out/kolide-enroll-1.0.0.pkg`.

Now, ensure that [osquery is installed](https://osquery.io/downloads/) on the target host, and run the generated installer package to configure the osquery installation.

Note: If you want to enroll the macOS host that this demo is running on you may have to edit the `/etc/hosts` file as specified in the output when generating the installer.

### Add Linux Hosts

Soon we will introduce package generation for configuring Linux osquery hosts to operate with this demo.

## Testing with Email (Optional)

Email setup is not required to demo Fleet. For those who would like to demo Fleet with a simulated email server, `./demo.sh up` starts a Mailhog container that facilitates this. In a production Fleet deployment, you would use your normal SMTP server.

### Set Up Email

To configure Fleet with this demo email server:

1. In Fleet, navigate to Admin -> App Settings (`/admin/settings`).
2. Make up a Sender Address (eg. `kolide@yourdomain.com`).
2. Enter SMTP server `mailhog` and port `1025`.
3. Set Authentication Type to `None`.
4. Click "Update Settings"

When completed, the configuration should look like this:

<img width="802" alt="Fleet Mailhog email configuration" src="https://cloud.githubusercontent.com/assets/575602/22914173/ff30949c-f223-11e6-8f3f-27675d6dbedb.png">

### Viewing Emails

Mailhog starts a UI available at port `8025` on your docker host ([http://localhost:8025](http://localhost:8025) if you are on the docker host) for viewing the emails "sent" through its SMTP server. If email is properly configured, you should see a test message from Fleet in this UI.
