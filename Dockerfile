ARG PERL_VERSION=5.36
FROM perl:${PERL_VERSION} as build

RUN apt update && apt upgrade -y && \
    apt install -y build-essential libpq-dev

# deploy the application
COPY t            /var/lib/coresmokedb-api/t/
COPY lib          /var/lib/coresmokedb-api/lib/
COPY bin          /var/lib/coresmokedb-api/bin/
COPY environments /var/lib/coresmokedb-api/environments/
COPY vendor       /var/lib/coresmokedb-api/vendor/
COPY config.yml   /var/lib/coresmokedb-api/
ADD --chmod=0600 private-config/.pgpass /var/lib/coresmokedb-api/environments/

# install dependencies
COPY cpanfile*    /var/lib/coresmokedb-api/
WORKDIR /var/lib/coresmokedb-api/
RUN cpanm -L local JSON::PP
RUN cpanm -L local --from $PWD/vendor/cache -qn --installdeps .

CMD [ \
    "perl", "-Ilocal/lib/perl5", "local/bin/plackup", "-s", "Starman", "-p", "5050", \
    "-E", "docker", "bin/app.psgi" \
]
