-- Selection order within a visit; photos display in this order.
alter table photos add column position int not null default 0;
