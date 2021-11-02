FROM debian:buster

# Install gosu
# ENV GOSU_VERSION=1.11

RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates wget gnupg2 gosu\
	&& rm -rf /var/lib/apt/lists/* \
    # verify that the binary works
    && gosu nobody true

# Install postgres 9.4, 9.5, 9.6 clients.  This is so that barman can use the
# appropriate version when using pg_basebackup.
# Install some other requirements as well.
#   cron: For scheduling base backups
#   gcc: For building psycopg2
#   libpq-dev: Needed to build/run psycopg2
#   libpython-dev: For building psycopg2
#   openssh-client: Needed to rsync basebackups from the database servers
#   openssh-server: Needed for ssh/rsync WAL archiving
#   python: Needed to run barman
#   rsync: Needed to rsync basebackups from the database servers
#   gettext-base: envsubst
RUN bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ buster-pgdg main" >> /etc/apt/sources.list.d/pgdg.list' \
	&& (wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -) \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends \
		cron \
		gcc \
		libpq-dev \
		libpython3-dev \
		openssh-client \
		openssh-server \
		postgresql-client-9.5 \
		postgresql-client-9.6 \
		postgresql-client-10 \
		postgresql-client-11 \
		postgresql-client-12 \
		python3 \
        python3-distutils \
		rsync \
        gettext-base \
        procps \
        prometheus-node-exporter \
	&& rm -rf /var/lib/apt/lists/* \
	&& rm -f /etc/crontab /etc/cron.*/* \
	&& sed -i 's/\(.*pam_loginuid.so\)/#\1/' /etc/pam.d/cron \
    && mkdir -p /etc/barman.d

# Set up some defaults for file/directory locations used in entrypoint.sh.
ENV \
	BARMAN_VERSION=2.15 \
	BARMAN_HOME_DIR=/var/lib/barman \
	BARMAN_DATA_DIR=/barman_data \
	BARMAN_LOG_DIR=/var/log/barman \
    BARMAN_CRON_SCHEDULE="* * * * *" \
    BARMAN_BACKUP_SCHEDULE="0 0 1 * *" \
    BARMAN_LOG_LEVEL=INFO \
    BARMAN_BACKUP_OPTIONS="concurrent_backup" \
    BARMAN_RETENTION_POLICY="RECOVERY WINDOW of 3 MONTHS" \
    IMMEDIATE_FIRST_BACKUP="yes" \
    BARMAN_EXPORTER_LISTEN_ADDRESS="0.0.0.0" \
    BARMAN_EXPORTER_LISTEN_PORT=9780 \
    BARMAN_EXPORTER_CACHE_TIME=120 \
    NODE_EXPORTER_LISTEN_ADDRESS="0.0.0.0" \
    NODE_EXPORTER_LISTEN_PORT=9781 
    # BARMAN_RECOVERY_OPTIONS = "" \
	# BARMAN_CRON_SRC=/private/cron.d \
	# BARMAN_SSH_KEY_DIR=/private/ssh \
	# BARMAN_PGPASSFILE=/private/pgpass \
    # DB_HOST=pg \
    # DB_PORT=5432 \
    # DB_SUPERUSER=postgres \
    # DB_SUPERUSER_PASSWORD=postgres \
    # DB_SUPERUSER_DATABASE=postgres \
    # DB_REPLICATION_USER=standby \
    # DB_REPLICATION_PASSWORD=standby \
    # DB_SLOT_NAME=barman \
    # DB_BACKUP_METHOD=postgres
    # BARMAN_EXPORTER_SCHEDULE="*/5 * * * *" \
VOLUME ${BARMAN_HOME_DIR}
VOLUME ${BARMAN_DATA_DIR}
VOLUME /etc/barman.d

EXPOSE 9780/tcp
EXPOSE 9781/tcp

COPY install_barman.sh /tmp/
RUN /tmp/install_barman.sh && rm /tmp/install_barman.sh
COPY barman.conf.template /etc/barman.conf.template
# COPY pg.conf.template /etc/barman.d/pg.conf.template
# COPY wal_archiver.py /usr/local/lib/python3.7/dist-packages/barman/wal_archiver.py

# Install barman exporter
RUN pip install barman-exporter

# ENV TINI_VERSION v0.18.0
# ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
# ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini.asc /tini.asc
# RUN gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 595E85A6B1B4779EA4DAAEC70B588DFF0527A9B7 \
#  && gpg --verify /tini.asc \
#  && chmod +x /tini

CMD tail -f ${BARMAN_LOG_DIR}/barman.log
COPY entrypoint.sh /
WORKDIR ${BARMAN_HOME_DIR}

# Install the entrypoint script.  It will set up ssh-related things and then run
# the CMD which, by default, starts cron.  The 'barman -q cron' job will get
# pg_receivexlog running.  Cron may also have jobs installed to run
# 'barman backup' periodically.
ENTRYPOINT ["/entrypoint.sh"]
