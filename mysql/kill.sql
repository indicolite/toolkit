select concat('kill ',i.trx_mysql_thread_id,';') from information_schema.innodb_trx i,
  (select 
         id, time
     from
         information_schema.processlist
     where
         time = (select 
                 max(time)
             from
                 information_schema.processlist
             where
                 state = 'Waiting for table metadata lock'
                     and substring(info, 1, 5) in ('alter' , 'optim', 'repai', 'lock ', 'drop ', 'creat'))) p
  where timestampdiff(second, i.trx_started, now()) > p.time
  and i.trx_mysql_thread_id  not in (connection_id(),p.id);

select
    concat('kill ', a.owner_thread_id, ';')
from
    information_schema.metadata_locks a
        left join
    (select
        b.owner_thread_id
    from
        information_schema.metadata_locks b, information_schema.metadata_locks c
    where
        b.owner_thread_id = c.owner_thread_id
            and b.lock_status = 'granted'
            and c.lock_status = 'pending') d ON a.owner_thread_id = d.owner_thread_id
where
    a.lock_status = 'granted'
        and d.owner_thread_id is null;
