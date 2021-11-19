#!/bin/bash

echo "Starting SSH server"
/etc/init.d/ssh start

echo "Setting ownership/permissions on ${BARMAN_DATA_DIR} and ${BARMAN_HOME_DIR} and ${BARMAN_LOG_DIR}"

install -d -m 0750 -o barman -g barman ${BARMAN_DATA_DIR}
install -d -m 0700 -o barman -g barman ${BARMAN_HOME_DIR}
install -d -m 0755 -o barman -g barman ${BARMAN_LOG_DIR}
chown -R barman:barman ${BARMAN_HOME_DIR}
chown -R barman:barman /etc/barman.d

echo "Generating Barman configurations"
cat /etc/barman.conf.template | envsubst > /etc/barman.conf

# if [[ -d ${BARMAN_DATA_DIR}/.pgtemplates ]]; then
#     for f in `ls ${BARMAN_DATA_DIR}/.pgtemplates`; do
#         cat ${BARMAN_DATA_DIR}/.pgtemplates/${f} | envsubst > /etc/barman.d/${f}
#     done
# fi

SERVERS=`barman list-servers --minimal | tr -s '\n' ' '`
echo "Servers found: ${SERVERS}"
echo "Generating cron schedules"
echo "${BARMAN_CRON_SCHEDULE} barman /bin/bash -c 'for H in $SERVERS; do /usr/local/bin/barman receive-wal --create-slot \${H}; done'; /usr/local/bin/barman cron" > /etc/cron.d/barman
echo "${BARMAN_BACKUP_SCHEDULE} barman ${BARMAN_BACKUP_SCHEDULE_EXTRA} /usr/local/bin/barman cron && /usr/local/bin/barman backup all" >> /etc/cron.d/barman

# cat /etc/barman.d/pg.conf.template | envsubst > /etc/barman.d/${DB_HOST}.conf
# if [[ "${BARMAN_RECOVERY_OPTIONS}" != "" ]]; then
#     echo "recovery_options = ${BARMAN_RECOVERY_OPTIONS}" >> /etc/barman.conf
# fi
# echo "${DB_HOST}:${DB_PORT}:*:${DB_SUPERUSER}:${DB_SUPERUSER_PASSWORD}" > ${BARMAN_DATA_DIR}/.pgpass
# echo "${DB_HOST}:${DB_PORT}:*:${DB_REPLICATION_USER}:${DB_REPLICATION_PASSWORD}" >> ${BARMAN_DATA_DIR}/.pgpass
if [[ -f ${BARMAN_HOME_DIR}/.pgpass ]]; then
    chmod 600 ${BARMAN_HOME_DIR}/.pgpass
fi

if [[ -d ${BARMAN_HOME_DIR}/.ssh/ ]]; then
    echo "Setting up Barman SSH dir"
    chmod 700 ~barman/.ssh
    chown barman:barman -R ~barman/.ssh
    if [[ -f ${BARMAN_HOME_DIR}/.ssh/id_rsa ]]; then
        echo "Setting up Barman private key"
        chmod 600 ~barman/.ssh/id_rsa
    fi
fi

echo "Checking/Creating replication slot"
for H in $SERVERS; do
    barman replication-status ${H} --minimal --target=wal-streamer | grep barman || barman receive-wal --create-slot ${H}
    barman replication-status ${H} --minimal --target=wal-streamer | grep barman || barman receive-wal --reset ${H}

    barman cron
    # Has to be run before barman can work properly in `streaming only` mode`
    if [[ `barman check $H | grep "WAL archive: FAILED"` != "" ]]; then
        barman switch-wal --force --archive --archive-timeout 120 ${H}
    fi
done

# run barman exporter every BARMAN_EXPORTER_CACHE_TIME 
exec /usr/local/bin/barman-exporter -l ${BARMAN_EXPORTER_LISTEN_ADDRESS}:${BARMAN_EXPORTER_LISTEN_PORT} -c ${BARMAN_EXPORTER_CACHE_TIME} &
echo "Started Barman exporter on ${BARMAN_EXPORTER_LISTEN_ADDRESS}:${BARMAN_EXPORTER_LISTEN_PORT}"

# run prometheus-node-exporter for use with the barman grafana dashboard
prometheus-node-exporter --web.listen-address="${NODE_EXPORTER_LISTEN_ADDRESS}:${NODE_EXPORTER_LISTEN_PORT}" 2>/dev/null &
echo "Started prometheus-node-exporter on ${NODE_EXPORTER_LISTEN_ADDRESS}:${NODE_EXPORTER_LISTEN_PORT}"

echo "Initializing done"

if [[ ${IMMEDIATE_FIRST_BACKUP} == "yes" ]]; then
    for H in $SERVERS; do
        if [[ "`barman list-backups $H`" == "" ]]; then
            echo "Running first backup for server ${H}..."
            barman cron && barman backup --wait ${H}
            echo "...done"
        fi
    done
fi

echo "Starting cron service..."
cron -L 4

exec "$@"
