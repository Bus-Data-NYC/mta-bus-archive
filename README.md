## Download a Bus Time archive

    make init

Oddly, I'd decided that data.mytransit.nyc should organize Bus Time archives by UTC date, so we'll actually be getting the evening of the 2016-05-24 to the evening of 2016-05-25, NYC time.

```
make csv/bus_time_YYYYMMDD.csv
```


    sh ./import_archive.sh DB_NAME bus_time_20160525.csv.xz
