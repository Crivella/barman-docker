# barman-docker

This container deploys [BaRMan](https://github.com/EnterpriseDB/barman), the "Backup and Recovery Manager for PostgreSQL.", together with [node exporter](https://github.com/prometheus/node_exporter) and [barman exporter](https://github.com/marcinhlybin/prometheus-barman-exporter) to export [prometheus](https://prometheus.io/) metrics.

## Typical use-case

Deploy a barman server to backup multiple projects using separate [PostgreSQL](https://www.postgresql.org/) databases.

### Installation

docker pull crivella1/docker-sh-exporter

### Build

    docker build -t crivella1/docker-sh-exporter 

### Run

    docker run --name sh-exporter -v HOST_MONITOR_DIR:MONITOR_DIR -v HOST_SCRIPT_DIR:/scripts -c HOST_COLLECT_DIR:COLLECT_DIR -p XXXXX:9781  -h docker-sh-exporter -t crivella1/docker-sh-exporter

## Container ports

| Container Port | Usage |
| --- | --- |
| 22 | Port used for SSH into the container. Needed if for recovering WAL files when restoring a backup (the target machine will copy the WAL files back via SSH)  |
| 9780 | Port used by `barman_exporter` to export the metrics |
| 9781 | Port used by `node_exporter` to export the metrics |

## Volumes

| Path | Description |
| --- | --- |
| `/var/lib/barman` | Holds the HOME of the barman user and can be used to mount the `.pg_pass` and `.ssh` into the container |
| `/barman_data` | Holds the generated backups. Can be used to store the backups on an bind-mounted volume |
| `/etc/barman.d` | Hold's the configuration files for the backup-targets. Can be ued to mount and manage the target from an external directory |

## Variables

| Variable | Values | Usage |
| --- | --- | --- |
| `BARMAN_VERSION` | `2.15` | The version of barman that will be installed and used |
| `BARMAN_HOME_DIR` | `/var/lib/barman` | The home directory of the barman user. Used for the `.pg_pass` and `.ssh/*` files |
| `BARMAN_DATA_DIR` | `/barman_data` | Directory where barman will store the backup files |
| `BARMAN_LOG_DIR` | `/var/log/barman` | Directory where barman saves the generated logs |
| `BARMAN_CRON_SCHEDULE` | `* * * * *` | Schedule with which the `barman cron`  ([see docs](https://docs.pgbarman.org/release/3.9.0/#general-commands))command will be run |
| `BARMAN_BACKUP_SCHEDULE` | `"0 0 * * 6"` | Schedule with which barman will run a full backup |
| `BARMAN_BACKUP_SCHEDULE_EXTRA` | `[ $(date +\%d) -le 07 ] &&` | This parameter is passed before the barman backup command in the CRON schedule. It can be used for more advanced configuration, eg. the default value will make it soo backups are ran only the first week of the month (in combination with the weekly schedule in `BARMAN_BACKUP_SCHEDULE`) |
| `BARMAN_LOG_LEVEL` | `INFO` | The log level for barman |
| `BARMAN_BACKUP_OPTIONS` | `concurrent_backup` | The backup option passed to barman in the config file ([see documentation](https://docs.pgbarman.org/release/3.9.0/#backup-features)). |
| `BARMAN_RETENTION_POLICY` | `RECOVERY WINDOW of 2 MONTHS` | The retention policy for the backups |
| `IMMEDIATE_FIRST_BACKUP` | `yes[no]` | Whether barman will run a first full backup if one does not exists already (for every target server) |
| `BARMAN_EXPORTER_LISTEN_ADDRESS` | `0.0.0.0` | The address from which barman_exporter will listen to GET requests (0.0.0.0 == ALL) |
| `BARMAN_EXPORTER_LISTEN_PORT` | `9780` | The port from which barman_exporter will listen to GET requests |
| `BARMAN_EXPORTER_CACHE_TIME` | `120` | The time in seconds barman_exporter will cache information before querying barman again |
| `NODE_EXPORTER_VERSION` | `1.3.1` | The version of node_exporter that will be installed the first time the container is launched (Must be a number [github release version number](https://github.com/prometheus/node_exporter/releases)) |
| `NODE_EXPORTER_ARCH` | `linux-amd64` | The system architecture (decides which arch version of node_exporter is installed) |
| `NODE_EXPORTER_LISTEN_ADDRESS` | `0.0.0.0` | The address from which node_exporter will listen to GET requests (0.0.0.0 == ALL) |
| `NODE_EXPORTER_LISTEN_PORT` | `9781` | The port from which node_exporter will listen to GET requests |
