#!/bin/bash
################################################################################
#   ____    ____    _____                                                      #
#  /\  _`\ /\  _`\ /\  __`\                                                    #
#  \ \ \L\_\ \ \L\_\ \ \/\ \    ___      __      ___ ___      __    ____       #
#   \ \ \L_L\ \  _\L\ \ \ \ \ /' _ `\  /'__`\  /' __` __`\  /'__`\ /',__\      #
#    \ \ \/, \ \ \L\ \ \ \_\ \/\ \/\ \/\ \L\.\_/\ \/\ \/\ \/\  __//\__, `\     #
#     \ \____/\ \____/\ \_____\ \_\ \_\ \__/.\_\ \_\ \_\ \_\ \____\/\____/     #
#      \/___/  \/___/  \/_____/\/_/\/_/\/__/\/_/\/_/\/_/\/_/\/____/\/___/      #
#                                                                              #
# FILE:        build_geonames.sh                                               #
#                                                                              #
# USAGE:       ./build_geonames.sh                                             #
#                                                                              #
# DESCRIPTION: utility to download current geonames data, build geonames       #
#              database in Postgresql/Postgis, create geometry columns,        #
#              spatially index and cluster.  It finishes by assigning          #
#              ownership of the database, all tables, sequences and views      #
#              to a user-specified database user.                              #
#                                                                              #
# REQUIREMENTS:PostGIS 2.x (and dependencies)                                  #
#                                                                              #
# ASSUMPTIONS: PostgreSQL >= 9.x and PostGIS >= 2.x                            #
#                                                                              #
# SUGGESTIONS: Running this as postgres user from shell on server hosting      #
#              PostgreSQL and PostGIS makes this extremely easy.  Though       #
#              not required, it will (presumably) prevent the operation from   #
#              prompting for password assuming you have correctly configured   #
#              pg_hba.conf.  If not possible, reverse psql statements          #
#              below, (i.e., psql -U <user> -h <host> -p <port>, etc.).        #
#                                                                              #
# Jack Varga <jack.varga at gmail dot com> Fri Dec  7 10:52:15 MST 2012        #
################################################################################

    
WORKPATH="/work" # local path
VMWORKPATH="/work" # Should be absolute path ON THE VM not the local machine!
TMPPATH="tmp"
WORKDIR=${WORKPATH}/${TMPPATH}
POSTALCODEPATH="pc"
POSTALCODEDIR=${WORKPATH}/${POSTALCODEPATH}
POSTALCODES=US.zip
PREFIX="_"
DBHOST="localhost"
DBPORT="5432"
DBNAME="geonames"
TZ="America/Los Angeles"
PGVERSION="12.2"
PGISVERSION='2.5'
DBUSER="postgres"
GEOROLE="georole"
GEOUSER="geouser"
GEOPASSWORD="geonames"
DEVROLE="geodev"
DEVUSER="geoadmin"
DEVPASSWORD="administrator"
POSTGISPATH="/usr/share/postgresql/${PGVERSION}/contrib/postgis-${PGISVERSION}"
FILES="allCountries.zip alternateNames.zip admin1CodesASCII.txt admin2Codes.txt countryInfo.txt featureCodes_en.txt timeZones.txt iso-languagecodes.txt"
TABLES="admin1codes admin2codes alternatename continentcodes countryinfo featurecodes postalcodes geoname languagecodes timezones"

for i in ${WORKDIR}/*.zip; do echo ${i}; done

echo -e "+----CREATE ${DBNAME} DATABASE (step 1 of 8)----------+\n"

psql -U $DBUSER -h $DBHOST -p $DBPORT <<EOT
DROP DATABASE ${DBNAME}; 
DROP ROLE IF EXISTS ${GEOROLE};
DROP USER IF EXISTS ${GEOUSER};
DROP ROLE IF EXISTS ${DEVROLE};
DROP USER IF EXISTS ${DEVUSER};
EOT

psql -U $DBUSER -h $DBHOST -p $DBPORT -c \
    "CREATE DATABASE ${DBNAME} WITH TEMPLATE = template0 ENCODING = 'UTF8';" 

# Create postgis extension
psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
  CREATE OR REPLACE LANGUAGE plpgsql;
  CREATE EXTENSION postgis;
EOT

echo -e "\n+-----CREATE TABLES and SEQUENCES (step 2 of 8)----------+\n"

psql -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT

DROP TABLE IF EXISTS geoname CASCADE;
CREATE TABLE geoname (
    id SERIAL NOT NULL,
    geonameid integer NOT NULL,
    name varchar(200),
    asciiname varchar(200),
    alternatenames text,
    latitude double precision,
    longitude double precision,
    fclass character(1),
    fcode varchar(10),
    country varchar(2),
    cc2 varchar(200), -- was 60
    admin1 varchar(20),
    admin2 varchar(80),
    admin3 varchar(20),
    admin4 varchar(20),
    population bigint,
    elevation integer,
    gtopo30 integer,
    timezone varchar(40),
    moddate date,
    PRIMARY KEY (geonameid)
);

DROP TABLE IF EXISTS alternatename;
CREATE TABLE alternatename (
    id SERIAL NOT NULL,
    alternatenameid integer NOT NULL,
    geonameid integer,
    isolanguage varchar(7),
    alternatename varchar(200),
    ispreferredname boolean,
    isshortname boolean,
    iscolloquial boolean,
    ishistoric boolean,
    PRIMARY KEY (alternatenameid)
);
                         
DROP TABLE IF EXISTS countryinfo;
CREATE TABLE countryinfo (
    id SERIAL NOT NULL,
    country_code character(2) NOT NULL,
    iso3 character(3),
    iso_numeric integer,
    fips character(2),
    country_name varchar(50),
    capital varchar(100),
    areainsqkm double precision,
    population integer,
    continent character(2),
    tld character(4),
    currency_code character(3),
    currency_name varchar(20),
    phone varchar(20),
    postal_code_fmt varchar(60),
    postal_code_rgx varchar(200),
    languages varchar(100),
    geonameid integer NOT NULL,
    neighbors varchar(75),
    equiv_fips_code character(2),
    PRIMARY KEY (country_code)
);

DROP TABLE IF EXISTS admin1codes;
CREATE TABLE admin1codes (
    id SERIAL NOT NULL,
    code character(14) NOT NULL, -- was 10
    name text,
    nameascii text,
    geonameid integer,
    PRIMARY KEY (code)
);

DROP TABLE IF EXISTS admin2codes;
CREATE TABLE admin2codes (
    id SERIAL NOT NULL,
    code varchar(40) NOT NULL,
    name text NOT NULL,
    alternatename text,
    geonameid integer NOT NULL,
    PRIMARY KEY (code)
);
                                     
DROP TABLE IF EXISTS featurecodes;
CREATE TABLE featurecodes (
   id SERIAL NOT NULL,
   code CHAR(7),
   name VARCHAR(200),
   description TEXT,
   PRIMARY KEY (code)
);
                                           
DROP TABLE IF EXISTS timezones;
CREATE TABLE timezones (
    id SERIAL NOT NULL,
    countrycode character(2),
    timezoneid varchar(200) NOT NULL,
    gmt_offset numeric(3,1),
    dst_offset numeric(3,1),
    raw_offset numeric(3,1),
    PRIMARY KEY (timezoneid)
);
                   
DROP TABLE IF EXISTS postalcodes;
CREATE TABLE postalcodes (
    id SERIAL NOT NULL,
    countrycode character(2) NOT NULL,
    postalcode varchar(20) NOT NULL,
    placename varchar(180) NOT NULL,
    admin1name varchar(100),
    admin1code varchar(20),
    admin2name varchar(100),
    admin2code varchar(20),
    admin3name varchar(100),
    admin3code varchar(20),
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    accuracy smallint,
    PRIMARY KEY (id)
);

DROP TABLE IF EXISTS languagecodes;
CREATE TABLE languagecodes (
    id SERIAL NOT NULL,
    iso_639_3 char(3),
    iso_639_2 varchar(10),
    iso_639_1 varchar(10),
    language_name varchar(100),
    PRIMARY KEY (language_name)
);

/* 
  Add foreign key constraints 
*/
ALTER TABLE ONLY countryinfo ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
ALTER TABLE ONLY alternatename ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
--ALTER TABLE ONLY admin2codes ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
ALTER TABLE ONLY admin1codes ADD CONSTRAINT fk_geonameid FOREIGN KEY (geonameid) REFERENCES geoname(geonameid);
EOT

# check if needed directories do already exsist
echo -e "\n\nChecking to see if download directories (${WORKPATH}) exists."
if [ -d "${WORKPATH}" ]; then
    echo "${WORKPATH} exists..."
    sleep 0
else
    echo "$WORKPATH and subdirectories will be created..."
    mkdir -p ${WORKPATH}
    mkdir -p ${WORKDIR}
    mkdir -p ${POSTALCODEDIR}
    echo "created ${WORKPATH}"
    echo "created ${WORKDIR}"
    echo "created ${POSTALCODEDIR}"
fi
echo
echo -e "\n+----DOWNLOADING, UNARCHIVING and PREPARING GEONAMES RAW DATA (step 3 of 8)------+\n"

cd ${WORKDIR}

for i in ${FILES}
do
    # Get most recent file(s). Use wget's inherent timestamp check.  If remote file 
    # is new clobber existing, otherwise leave it alone.   
    wget -N --timestamping --progress=dot:mega "http://download.geonames.org/export/dump/$i" 
    case "$i" in 
        iso-languagecodes.txt)
            tail -n +2 $WORKDIR/iso-languagecodes.txt > $WORKDIR/iso-languagecodes.txt.tmp;
            ;;
        countryInfo.txt)
            grep -v '^#' $WORKDIR/countryInfo.txt | head -n -2 > $WORKDIR/countryInfo.txt.tmp;
            ;;
        timeZones.txt)
            tail -n +2 $WORKDIR/timeZones.txt > $WORKDIR/timeZones.txt.tmp;
            ;;
    esac
done

# Test for zip files and unzip
for i in ${WORKDIR}/*.zip; do echo ${i}; unzip -d${WORKDIR} -o ${i}; done

# This has only been tested with US postal codes (i.e., US.zip) though should 
# work with any country postal codes. Again, uses wget to check timesamps.
cd ${POSTALCODEDIR}
wget -N --timestamping --progress=dot:mega "http://download.geonames.org/export/zip/${POSTALCODES}"
unzip -o ${POSTALCODES} US.txt
# US.txt has an extra tab column that is blank.  Get rid of it.
# cat US.txt | sed "s/\t\t*/\t/g" > tmp.txt ; mv -f tmp.txt US.txt

echo -e "\n+----POPULATE TABLES (step 4 of 8)----------+\n"

psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
copy geoname (geonameid,name,asciiname,alternatenames,latitude,longitude,fclass,fcode,country,cc2,admin1,admin2,admin3,admin4,population,elevation,gtopo30,timezone,moddate) from '${VMWORKPATH}/${TMPPATH}/allCountries.txt' null as '';
EOT

psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
copy postalcodes (countrycode,postalcode,placename,admin1name,admin1code,admin2name,admin2code,admin3name,admin3code,latitude,longitude,accuracy) from '${VMWORKPATH}/${POSTALCODEPATH}/US.txt' null as '';
copy timezones (countrycode,timeZoneId,GMT_offset,DST_offset,raw_offset) from '${VMWORKPATH}/${TMPPATH}/timeZones.txt.tmp' null as '';
copy featureCodes (code,name,description) from '${VMWORKPATH}/${TMPPATH}/featureCodes_en.txt' null as '';
copy admin1codes (code,name,nameAscii,geonameid) from '${VMWORKPATH}/${TMPPATH}/admin1CodesASCII.txt' null as '';
copy admin2codes (code,name,alternatename,geonameid) from '${VMWORKPATH}/${TMPPATH}/admin2Codes.txt' null as '';
copy languagecodes (iso_639_3,iso_639_2,iso_639_1,language_name) from '${VMWORKPATH}/${TMPPATH}/iso-languagecodes.txt.tmp' null as '';
copy countryInfo (country_code,iso3,iso_numeric,fips,country_name,capital,areainsqkm,population,continent,tld,currency_code,currency_name,phone,postal_code_fmt,postal_code_rgx,languages,geonameid,neighbors,equiv_fips_code) from '${VMWORKPATH}/${TMPPATH}/countryInfo.txt.tmp' null as '';
copy alternatename (alternatenameid,geonameid,isoLanguage,alternateName,isPreferredName,isShortName,isColloquial,isHistoric) from '${VMWORKPATH}/${TMPPATH}/alternateNames.txt' null as '';
INSERT INTO continentCodes (code,name,geonameid) VALUES ('AF', 'Africa', 6255146);
INSERT INTO continentCodes (code,name,geonameid) VALUES ('AS', 'Asia', 6255147);
INSERT INTO continentCodes (code,name,geonameid) VALUES ('EU', 'Europe', 6255148);
INSERT INTO continentCodes (code,name,geonameid) VALUES ('NA', 'North America', 6255149);
INSERT INTO continentCodes (code,name,geonameid) VALUES ('OC', 'Oceania', 6255150);
INSERT INTO continentCodes (code,name,geonameid) VALUES ('SA', 'South America', 6255151);
INSERT INTO continentCodes (code,name,geonameid) VALUES ('AN', 'Antarctica', 6255152);
EOT

echo -e "\n+----REMOVING EXTRANEOUS CODES (step 4.5 of 8)----------+\n"
psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
DELETE FROM alternatename WHERE alternatename.geonameid 
IN (SELECT geonameid FROM geoname 
    WHERE fcode NOT IN ('ADM1', 'ADM1H','ADM2','ADM2H','ADM3','ADM3H','ADM4','ADM4H','ADM5','ADM5H','ADMD','ADMDH',
                        'LTER','PCL','PCLD','PCLF','PCLH','PCLI','PCLIX','PCLS','PRSH','TERR','ZN','ZNB',
                        'PPL','PPLA','PPLA2','PPLA3','PPLA4','PPLA5','PPLC','PPLCH','PPLF','PPLG','PPLH','PPLL',
                        'PPLQ','PPLR','PPLS','PPLW','PPLX','STLMT'));
DELETE FROM geoname WHERE fcode NOT IN ('ADM1', 'ADM1H','ADM2','ADM2H','ADM3','ADM3H','ADM4','ADM4H','ADM5','ADM5H','ADMD','ADMDH',
                        'LTER','PCL','PCLD','PCLF','PCLH','PCLI','PCLIX','PCLS','PRSH','TERR','ZN','ZNB',
                        'PPL','PPLA','PPLA2','PPLA3','PPLA4','PPLA5','PPLC','PPLCH','PPLF','PPLG','PPLH','PPLL',
                        'PPLQ','PPLR','PPLS','PPLW','PPLX','STLMT');
EOT

echo -e "\n+----CREATING INDEXES ON GEONAME IDS (step 5 of 8)---------+\n"

psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
CREATE INDEX idx_countryinfo ON countryinfo USING btree (geonameid);
CREATE INDEX idx_alternatename ON alternatename USING btree (geonameid);
CREATE INDEX idx_admin1codes ON admin1codes USING btree (geonameid);
CREATE INDEX idx_admin1codes_name ON admin1codes USING btree (name);
CREATE INDEX idx_admin2codes ON admin2codes USING btree (geonameid);
CREATE INDEX idx_admin2codes_name ON admin2codes USING btree (name);
CREATE INDEX idx_alternatename_search ON alternatename USING btree (alternatename varchar_pattern_ops);
CREATE INDEX idx_geoname_search ON geoname USING btree (name varchar_pattern_ops)
EOT

echo -e "\n+----CREATING INDEXES ON featurecodes (step 5.5 of 8)---------+\n"

psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
ALTER TABLE geoname ADD COLUMN featurecodeid varchar(11);
UPDATE geoname SET featurecodeid = fclass || '.' || fcode;
CREATE INDEX idx_featurecodeid ON geoname USING btree (featurecodeid);
CREATE INDEX idx_code ON featurecodes USING btree (code);
EOT


echo -e "\n+----CREATING SPATIAL GEOMETRIES (step 6 of 8)----------+\n"


psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
SELECT AddGeometryColumn ('public','geoname','the_geom',4326,'POINT',2);
UPDATE geoname SET the_geom = ST_PointFromText('POINT(' || longitude || ' ' || latitude || ')', 4326);
--UPDATE geoname SET the_geom = ST_SetSRID(ST_Point(longitude,latitude),4326);
ALTER TABLE geoname ALTER COLUMN the_geom SET not null;

SELECT AddGeometryColumn ('public','postalcodes','the_geom',4326,'POINT',2);
UPDATE postalcodes SET the_geom = ST_PointFromText('POINT(' || longitude || ' ' || latitude || ')', 4326);
--UPDATE postalcodes SET the_geom = ST_SetSRID(ST_Point(longitude,latitude),4326);
EOT

echo -e "+----INDEX and CLUSTER GEOMETRIES (step 7 of 8)\n"

psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
CREATE INDEX idx_geoname ON geoname USING gist(the_geom);
EOT

psql -e -U $DBUSER -h $DBHOST -p $DBPORT ${DBNAME} <<EOT
CLUSTER idx_geoname ON geoname;
CREATE INDEX idx_postalcodes ON postalcodes USING gist(the_geom);
ALTER TABLE postalcodes ALTER COLUMN the_geom SET not null;
CLUSTER idx_postalcodes ON postalcodes;
EOT

echo -e "\n+----PROCESS COMPLETE.-----------------------+\n"
exit 0
