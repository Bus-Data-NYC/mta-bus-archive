start_date=2015-01-05
num_days=21
for i in `seq 0 $num_days`
do
    date=`date +%Y-%m-%d -d "${start_date}+${i} days"`
    echo $(date) $date
    time ./get_waits.sh ts $date
done

