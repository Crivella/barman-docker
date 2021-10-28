#!/bin/bash

echo "Starting SSH server"
/etc/init.d/ssh start

echo "Setting ownership/permissions on ${BARMAN_DATA_DIR} and ${BARMAN_LOG_DIR}"

install -d -m 0700 -o barman -g barman ${BARMAN_DATA_DIR}
install -d -m 0755 -o barman -g barman ${BARMAN_LOG_DIR}

echo "Generating Barman configurations"
cat /etc/barman.conf.template | envsubst > /etc/barman.conf

if [[ -d ${BARMAN_DATA_DIR}/.pgtemplates ]]; then
    for f in `ls ${BARMAN_DATA_DIR}/.pgtemplates`; do
        cat ${BARMAN_DATA_DIR}/.pgtemplates/${f} | envsubst > /etc/barman.d/${f}
    done
fi

SERVERS=`barman list-servers | cut -d- -f1`
echo "Identified pg servers: ${SERVERS}"
echo "Generating cron schedules"
echo "${BARMAN_CRON_SCHEDULE} barman for H in $SERVERS; do /usr/local/bin/barman receive-wal --create-slot ${H}; done; /usr/local/bin/barman cron" >> /etc/cron.d/barman
echo "${BARMAN_BACKUP_SCHEDULE} barman cron && barman /usr/local/bin/barman backup all" >> /etc/cron.d/barman

# cat /etc/barman.d/pg.conf.template | envsubst > /etc/barman.d/${DB_HOST}.conf
# if [[ "${BARMAN_RECOVERY_OPTIONS}" != "" ]]; then
#     echo "recovery_options = ${BARMAN_RECOVERY_OPTIONS}" >> /etc/barman.conf
# fi
# echo "${DB_HOST}:${DB_PORT}:*:${DB_SUPERUSER}:${DB_SUPERUSER_PASSWORD}" > ${BARMAN_DATA_DIR}/.pgpass
# echo "${DB_HOST}:${DB_PORT}:*:${DB_REPLICATION_USER}:${DB_REPLICATION_PASSWORD}" >> ${BARMAN_DATA_DIR}/.pgpass
if [[ -f ${BARMAN_DATA_DIR}/.pgpass ]]; then
    chown barman:barman ${BARMAN_DATA_DIR}/.pgpass
    chmod 600 ${BARMAN_DATA_DIR}/.pgpass
fi

if [[ -d ${BARMAN_DATA_DIR}/.ssh/ ]]; then
    echo "Setting up Barman SSH dir"
    chmod 700 ~barman/.ssh
    chown barman:barman -R ~barman/.ssh
    if [[ -f ${BARMAN_DATA_DIR}/.ssh/id_rsa ]]; then
        echo "Setting up Barman private key"
        chmod 600 ~barman/.ssh/id_rsa
    fi
fi

echo "Checking/Creating replication slot"
for H in $SERVERS; do
    barman replication-status ${H} --minimal --target=wal-streamer | grep barman || barman receive-wal --create-slot ${H}
    barman replication-status ${H} --minimal --target=wal-streamer | grep barman || barman receive-wal --reset ${H}
    # Has to be run before barman can work properly in `streaming only` mode`
    # sleep 10

    barman cron && barman switch-wal --force --archive --archive-timeout 120 ${H}
done


echo "Initializing done"

if [[ ${IMMEDIATE_FIRST_BACKUP} == "yes" ]]; then
    echo "Running first backup..."
    barman cron && barman backup --wait all
    echo "...done"
fi

# run barman exporter every hour
exec /usr/local/bin/barman-exporter -l ${BARMAN_EXPORTER_LISTEN_ADDRESS}:${BARMAN_EXPORTER_LISTEN_PORT} -c ${BARMAN_EXPORTER_CACHE_TIME} &
echo "Started Barman exporter on ${BARMAN_EXPORTER_LISTEN_ADDRESS}:${BARMAN_EXPORTER_LISTEN_PORT}"

tail -f ${BARMAN_LOG_DIR}/barman.log
