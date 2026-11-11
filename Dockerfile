FROM twentycrm/twenty:v2.57.1

USER root
COPY fly-entrypoint.sh /usr/local/bin/twenty-fly-entrypoint
RUN chmod 755 /usr/local/bin/twenty-fly-entrypoint
USER 1000

ENTRYPOINT ["/usr/local/bin/twenty-fly-entrypoint"]
