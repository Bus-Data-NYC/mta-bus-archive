#

drop table if exists trip_lookup;
create table trip_lookup (trip_id varchar(255) not null key, trip_index int not null) engine=MyISAM;
insert trip_lookup select trip_id, trip_index from trips group by trip_id;
repair table trip_lookup;
optimize table trip_lookup;
select trip_id, trip_index from trip_lookup order by trip_id into outfile 'trip_lookup.tsv' fields terminated by ',';
sudo mv /var/lib/mysql/ts/trip_lookup.tsv .

