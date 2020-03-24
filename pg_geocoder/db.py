import psycopg2

class Geoname (object):
    def __init__ (self, **kwargs):
        self.name = kwargs["name"]
        self.country = kwargs["country"]
        self.admin1 = kwargs.get("admin1",None)
        self.admin2 = kwargs.get("admin2",None)
        self.admin3 = kwargs.get("admin3",None)
        self.admin4 = kwargs.get("admin4",None)
        self.longitude = kwargs["longitude"]
        self.latitude = kwargs["latitude"]
        self.population = kwargs["population"]
        self.alternatenames = kwargs.get("alternatenames", "").split(",")
        self.fcode = kwargs.get("fcode",None)


class GeoDB (object):
    COUNTRY_EXCEPTIONS = ["England"]
    COUNTRY_CODES = ["PCL", "PCLD", "PCLF", "PCLH", "PCLI", "PCLIX", "PCLS"]
    
    def __init__ (self, dbname="geonames", user="postgres", host="localhost", port="5432", password="pass"):
        conn_str = "dbname='{0}' host='{1}' user='{2}' port='{3}' password='{4}'".format(dbname, host, user, port, password)
        print(conn_str)
        self._db = psycopg2.connect(conn_str)
        self._cursor = self._db.cursor()
        self._country_lut = {}
    
    def filterCountry (self, rows):
        fn = lambda x: x.name in GeoDB.COUNTRY_EXCEPTIONS or x.fcode in GeoDB.COUNTRY_CODES
        return filter(fn, rows)

    def queryPlaceFuzzy (self, name):
        self._cursor.execute(
            """
            SELECT DISTINCT name, country, latitude, longitude, population, admin1, admin2, admin3, admin4, geoname.alternatenames, fcode
            FROM geoname
            INNER JOIN alternatename
            ON alternatename.geonameid = geoname.geonameid
            WHERE alternatename LIKE %s
            """, (name ,)
        )
        res = []
        for row in self._cursor.fetchall():
            res.append(Geoname(
                name = row[0], country = row[1],
                latitude = row[2], longitude = row[3], 
                population = row[4], 
                admin1 = row[5], admin2 = row[6], 
                admin3 = row[7], admin4 = row[8],
                alternatenames = row[9], 
                fcode = row[10]
            ))
        return res

    def queryCountryFuzzy (self, name):
        return self.filterCountry(self.queryPlaceFuzzy(name))


    
def printGeoname (row, max_name_len = 20):
    name_str = "{0:>" + str(max_name_len) + "}"
    fmt = name_str + " | {1:>2} | {2:>3} | {3:>12} | {4:>4}"
    print(fmt.format(row.name, row.country, row.admin1, row.population, len(row.alternatenames)))
    
def printGeonames (rows):
    rows = list(rows)
    max_len = max(map(lambda v: len(v.name), rows))
    for r in rows:
        printGeoname(r, max_len)

        

