-- 3. Создание схемы exts и подключение модуля uuid-ossp
create schema if not exists exts;
create extension if not exists "uuid-ossp" with schema exts;

-- 4. Создание enum
create type day_of_week as enum (
	'Понедельник',
	'Вторник',
	'Среда',
	'Четверг',
	'Пятница',
	'Суббота',
	'Воскресенье'
);

create type courier_status as enum (
	'Свободен',
	'Доставляет',
	'Неактивен'
);

create type restaurant_status as enum (
	'Закрыт',
	'Открыт',
	'Не работает'
);

create type product_status as enum (
	'Доступен',
	'Недоступен'
);

create type order_status as enum (
	'Создан',
	'Собран',
	'Доставляется',
	'Завершен',
	'Отменен'
);

create type pay_status as enum (
	'Оплачен',
	'Не оплачен'
);

create type transaction_status as enum (
	'Ожидается оплата',
	'Успех',
	'Ошибка'
);

-- 2. Создание таблиц
create table product_category (
	product_category_id uuid primary key default exts.uuid_generate_v4(),
	product_category_name varchar(50) not null unique
);

create table address (
	address_id uuid primary key default exts.uuid_generate_v4(),
	street varchar(50) not null,
	house_number varchar(10) not null,
	apartment_office varchar(10)
);

create table company_details (
	company_details_id uuid primary key default exts.uuid_generate_v4(),
	inn varchar(10) not null,
	kpp char(9),
	account char(20) not null
);

create table client (
	client_id uuid primary key default exts.uuid_generate_v4(),
	login varchar(20) not null unique,
	password varchar(128) not null,
	phone_number char(11) not null unique
);

create table courier (
	courier_id uuid primary key default exts.uuid_generate_v4(),
	last_name varchar(30) not null,
	first_name varchar(30) not null,
	second_name varchar(30),
	phone_number char(11) not null unique,
	passport_series char(4) not null,
	passport_number char(6) not null,
	status courier_status not null default 'Свободен',
	hire_date date not null,
	dismissal_date date
);

create table restaurant (
	restaurant_id uuid primary key default exts.uuid_generate_v4(),
	restaurant_name varchar(50) not null,
	address_id uuid not null references address(address_id),
	description text,
	company_details_id uuid not null references company_details(company_details_id),
	rating numeric(3, 2) default 0 not null check (rating >= 0 and rating <= 5),
	status restaurant_status not null default 'Открыт'
);

create table client_address (
	client_id uuid not null references client(client_id) on delete cascade,
	address_id uuid not null references address(address_id) on delete cascade,
	primary key (client_id, address_id)
);

create table courier_pay (
	year int not null,
	month int not null check (month >= 1 and month <= 12),
	courier_id uuid not null references courier(courier_id) on delete cascade,
	amount numeric(8, 2) not null check (amount >= 0),
	primary key (year, month, courier_id)
);

create table courier_rate (
	assignment_date date not null,
	courier_id uuid not null references courier(courier_id) on delete cascade,
	rate numeric(2, 2) default 0.05 not null,
	primary key (assignment_date, courier_id)
);

create table opening_hours (
	restaurant_id uuid not null references restaurant(restaurant_id),
	day_of_week day_of_week not null,
	open_time time not null,
	close_time time not null,
	primary key (restaurant_id, day_of_week)
);

create table product (
	product_id uuid primary key default exts.uuid_generate_v4(),
	product_name varchar(100) not null,
	product_category_id uuid not null references product_category(product_category_id),
	price numeric(7, 2) not null check (price >= 0),
	restaurant_id uuid not null references restaurant(restaurant_id),
	photo_url text,
	rating numeric(3, 2) not null default 0 check (rating >= 0 and rating <= 5),
	status product_status not null default 'Доступен',
	description text
);

create table "order" (
	order_id uuid primary key default exts.uuid_generate_v4(),
	courier_id uuid not null references courier(courier_id),
	client_id uuid not null references client(client_id),
	address_id uuid not null references address(address_id),
	restaurant_id uuid not null references restaurant(restaurant_id),
	order_timestamp timestamp not null,
	delivery_timestamp timestamp,
	order_amount numeric(8, 2) not null check (order_amount >= 0),
	commission numeric(8, 2) not null,
	total_amount numeric(8, 2) not null check (total_amount >= 1000),
	status order_status not null default 'Создан',
	pay_status pay_status not null default 'Не оплачен',
	rating numeric(3, 2) not null default 0 check (rating >= 0 and rating <= 5),
	description text
);

create table order_structure(
	order_id uuid not null references "order"(order_id) on delete cascade,
	product_id uuid not null references product(product_id),
	quantity numeric(2, 0) not null check (quantity > 0),
	primary key (order_id, product_id)
);

create table review(
	review_id uuid primary key default exts.uuid_generate_v4(),
	client_id uuid not null references client(client_id),
	review_timestamp timestamp null,
	entity_id uuid not null,
	entity_type name not null,
	order_id uuid not null references "order"(order_id),
	description text,
	photo_url text,
	rating numeric(3, 2) not null default 0 check (rating >= 0 and rating <= 5)
);

create table payment(
	payment_id uuid primary key default exts.uuid_generate_v4(),
	payment_transaction text not null unique,
	order_id uuid not null references "order"(order_id),
	amount numeric(8, 2) not null check (amount > 0),
	payment_timestamp timestamp not null default current_timestamp,
	status transaction_status not null default 'Ожидается оплата'
);

-- 5. Создание пользователя reviewer и выдача прав доступа
create role reviewer with password 'NetoSQL2026';
alter role reviewer login;

grant all on schema kravtsova_food to reviewer;
grant all on all tables in schema kravtsova_food to reviewer;

grant usage on schema information_schema to reviewer;
grant select on all tables in schema information_schema to reviewer;

grant usage on schema pg_catalog to reviewer;
grant select on all tables in schema pg_catalog to reviewer;

grant usage on schema exts to reviewer;
grant execute on all functions in schema exts to reviewer;


-- 6. Генерация тестовых данных
create or replace procedure insert_test_data(value int) as $$
declare
	str text = 'абвгдеёжзийклмнопрстуфхцчшщъыьэюя';
	eng text = 'abcdefghijklmnopqrstuvwxyz';
	digits text = '0123456789';

	status_var courier_status;
	hire_date_var date;
	dismissal_date_var date;
	second_name_var varchar(30);
	restaurant_id_var uuid;
	rates_var numeric[] = array[0.05, 0.10, 0.20, 0.30, 0.40, 0.50];
	order_amount_var numeric(8, 2);
	comission_var numeric(8, 2);
	order_id_var uuid;
	order_timestamp_var timestamp;
	open_time_workday_var time;
	open_time_weekend_var time;
	close_time_workday_var time;
	close_time_weekend_var time;
	entity_type_var text;
	entity_id_var uuid;
	
	i record;
	j int;
	
begin
	for j in 1..value
	loop
		insert into product_category (product_category_name)
		values (left('Категория_' || floor(random()*1000) || repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 50))
		on conflict (product_category_name) do nothing;
		
		insert into client (login, password, phone_number)
		values (
			left('login_' || floor(random()*10000) || repeat(substring(eng, 1, ceil(random() * 26)::int), ceil(random() * 3)::int), 20),
			left(repeat(substring(eng || digits, 1, ceil(random() * 36)::int), ceil(random() * 3)::int), 128),
			ceil(random()*999999999 + 7000000000)::char(11)
		)
		on conflict (login) do nothing;
		
		insert into courier (last_name, first_name, second_name, phone_number, passport_series, passport_number, status, hire_date, dismissal_date)
		values (
			left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 30),
			left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 30),
			left(repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 30),
			ceil(random()*999999999 + 7000000000)::char(11),
			(ceil(random() * 8999) + 1000)::char(4),
			(ceil(random() * 899999) + 100000)::char(6),
			(enum_range(NULL::courier_status))[ceil(random() * cardinality(enum_range(NULL::courier_status)))],
			current_date - (random() * 180)::int,
			null
		)
		on conflict (phone_number) do nothing;
		
		insert into company_details (inn, kpp, account)
		values (
			(ceil(random() * 8999999999) + 1000000000)::char(10),
			(ceil(random() * 899999999) + 100000000)::char(9),
			left((ceil(random() * 8999999999) + 1000000000)::text || (ceil(random() * 8999999999) + 1000000000)::text, 20)
		);
    end loop;
		
	for j in 1..value*5
	loop
		insert into address (street, house_number, apartment_office)
		values (
			left('Улица_' || repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 50),
			(ceil(random() * 500) + 1)::char(10),
			(ceil(random() * 500) + 1)::char(10)
		);
	end loop;

	for i in (select client_id from client) 
	loop
		insert into client_address (client_id, address_id)
		values (
			i.client_id, 
			(select address_id from address order by random() limit 1)
		)
		on conflict (client_id, address_id) do nothing;
	end loop;
	
	for i in (select company_details_id from company_details limit value)
	loop
		open_time_workday_var := '08:00:00'::time + (ceil(random() * 4) || ' hours')::interval;
		close_time_workday_var := '20:00:00'::time + (ceil(random() * 4) || ' hours')::interval;
		open_time_weekend_var := '10:00:00'::time + (ceil(random() * 2) || ' hours')::interval;
		close_time_weekend_var := '21:00:00'::time + (ceil(random() * 2) || ' hours')::interval;

		insert into restaurant (restaurant_name, address_id, company_details_id, rating, status)
		values (
			left('Ресторан_' || repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 50),
			(select address_id from address order by random() limit 1),
			i.company_details_id,
			(random() * 5)::numeric(3, 2),
			(enum_range(NULL::restaurant_status))[ceil(random() * cardinality(enum_range(NULL::restaurant_status)))]
		) returning restaurant_id into restaurant_id_var;
		
		for j in 1..7
		loop
			insert into opening_hours (restaurant_id, day_of_week, open_time, close_time)
			values (
				restaurant_id_var, (enum_range(NULL::day_of_week))[j],
				case 
					when j >= 6 then open_time_weekend_var
					else open_time_workday_var 
				end,
				case 
					when j >= 6 then close_time_weekend_var 
					else close_time_workday_var
				end
			);
		end loop;
	end loop;

	for j in 1..value * 5 
	loop
		insert into product (product_name, product_category_id, price, restaurant_id, photo_url, rating, status)
		values (
			left('Блюдо_' || floor(random()*1000) || repeat(substring(str, 1, ceil(random() * 33)::int), ceil(random() * 3)::int), 100),
			(select product_category_id from product_category order by random() limit 1),
			(100 + random() * 5000)::numeric(7, 2),
			(select restaurant_id from restaurant order by random() limit 1),
			('https://photo-url.ru/product_' || floor(random()*1000) ||'.jpg'),
			(random() * 5)::numeric(3, 2),
			(enum_range(NULL::product_status))[ceil(random() * cardinality(enum_range(NULL::product_status)))]
		);
	end loop;

	for i in (select courier_id from courier) 
	loop
		insert into courier_rate (assignment_date, courier_id, rate)
		values (
			current_date - 180, 
			i.courier_id, 
			rates_var[ceil(random()*6)]
		)
		on conflict (assignment_date, courier_id) do nothing;
	end loop;
	
	for j in 1..value * 5 
	loop
		order_amount_var := (1000 + random() * 10000)::numeric(8, 2);
		order_id_var = exts.uuid_generate_v4();
		order_timestamp_var = current_timestamp - (random() * 10000 * interval '1 minute');
		
		insert into "order" (order_id, courier_id, client_id, address_id, restaurant_id, order_timestamp, delivery_timestamp, order_amount, commission, total_amount, status, pay_status, rating)
		values (
			order_id_var,
			(select courier_id from courier order by random() limit 1),
			(select client_id from client order by random() limit 1),
			(select address_id from address order by random() limit 1),
			(select restaurant_id from restaurant order by random() limit 1),
			order_timestamp_var,
			current_timestamp,
			order_amount_var, 
			order_amount_var * 0.1,
			order_amount_var * 1.1,
			(enum_range(NULL::order_status))[ceil(random() * cardinality(enum_range(NULL::order_status)))],
			(enum_range(NULL::pay_status))[ceil(random() * cardinality(enum_range(NULL::pay_status)))],
			(random() * 5)::numeric(3, 2)
		);

		insert into order_structure (order_id, product_id, quantity)
		values (
			order_id_var, 
			(select product_id from product order by random() limit 1), 
			ceil(random() * 3)
		);

		insert into payment (payment_transaction, order_id, amount, payment_timestamp, status)
		values (
			left('transaction-' || exts.uuid_generate_v4()::text, 50), 
			order_id_var,
			order_amount_var * 1.1,
			order_timestamp_var + (random() * interval '5 minutes'),
			(enum_range(NULL::transaction_status))[1]
		)
		on conflict (payment_transaction) do nothing;
		
		entity_type_var := (array['order', 'product', 'restaurant'])[ceil(random() * 3)];
		entity_id_var := case
			when entity_type_var = 'order' then order_id_var
			when entity_type_var = 'product' then (select product_id from order_structure where order_id = order_id_var limit 1)
			when entity_type_var = 'restaurant' then (select restaurant_id from "order" where order_id = order_id_var)
		end;

		insert into review (client_id, review_timestamp, entity_id, entity_type, order_id, photo_url, rating)
		values (
			(select client_id from "order" where order_id = order_id_var),
			current_timestamp, 
			entity_id_var,
			entity_type_var,
			order_id_var,
			('https://photo-url.ru/review_' || floor(random()*1000) ||'.jpg'),
			(random()*5)::numeric(3,2)
		);
	end loop;

	for i in 
		select courier_id from courier where courier_id not in (select courier_id from courier_pay) 
	loop
		for j in 1..6 
		loop
			insert into courier_pay (year, month, courier_id, amount)
            values (2026, j, i.courier_id, (40000 + random() * 50000)::numeric(8, 2));
        end loop;
    end loop;
end;
$$ language plpgsql;

call insert_test_data(100);

-- 7. Удаление тестовых данных	
create or replace procedure erase_test_data() as $$
begin 
    truncate table 
    	product_category,
    	client,
		courier,
		company_details,
		address,
		restaurant,
		opening_hours,
		client_address,
		courier_rate,
		product,
		"order",
		payment,
		order_structure,
		review,
    	courier_pay cascade;
    raise notice 'Все тестовые данные успешно удалены';
end;
$$ language plpgsql;

call erase_test_data();

-- 8. Триггер, который производит расчёт рейтингов по отзывам пользователей
create or replace function rating_change() returns trigger as $$
declare
	avg_rating_var numeric(3,2);
	target_id_var uuid;
	target_type_var name;
begin
	if tg_op = 'INSERT' or tg_op = 'UPDATE' then
		target_id_var := new.entity_id;
		target_type_var := new.entity_type;
	elsif tg_op = 'DELETE' then
		target_id_var := old.entity_id;
		target_type_var := old.entity_type;	
	end if;

	select coalesce(avg(rating), 0) 
	into avg_rating_var 
	from review 
	where entity_id = target_id_var and entity_type = target_type_var;

	if target_type_var = 'restaurant' then
		update restaurant 
		set rating = avg_rating_var 
		where restaurant_id = new.entity_id;
	elsif target_type_var = 'product' then
		update product 
		set rating = avg_rating_var 
		where product_id = new.entity_id;
	elsif target_type_var = 'order' then
		update "order" 
		set rating = avg_rating_var 
		where order_id = new.entity_id;
	end if;
    return null;
end;
$$ language plpgsql;

create or replace trigger tg_rating_change
after insert or update or delete on review
for each row execute function rating_change();

-- 9. Функция, возвращающая статистику
create or replace function get_statistic()
returns table (
	restaurant_name varchar(50),
	best_product_name varchar(100),
	total_amount numeric(8, 2),
	avg_amount numeric(8, 2),
	best_user varchar(20)
) as $$
begin
	return query
	with restaurant_statistics as (
		select 
			r.restaurant_id, 
			r.restaurant_name,
			coalesce(sum(o.order_amount), 0) as total_amount,
			coalesce(avg(o.order_amount), 0) as avg_amount
		from restaurant r
		left join "order" o on r.restaurant_id = o.restaurant_id 
		group by r.restaurant_id
	),
	popular_products as (
		select distinct on (p.restaurant_id)
			p.restaurant_id,
			p.product_name,
			sum(os.quantity)
		from product p
		join order_structure os on os.product_id = p.product_id
		group by p.restaurant_id, p.product_id
		order by p.restaurant_id, sum(os.quantity) desc, random()
	),
	active_users as (
		select distinct on (o.restaurant_id)
			o.restaurant_id,
			c.login,
			count(*)
		from "order" o
		join client c on c.client_id = o.client_id
		group by o.restaurant_id, c.client_id
		order by o.restaurant_id, count(*) desc, random()
	)
	select
		rs.restaurant_name,
		coalesce(pp.product_name, ' - ') as best_product_name,
		rs.total_amount,
		rs.avg_amount,
		coalesce(au.login, ' - ') as best_user
	from restaurant_statistics rs
	left join popular_products pp on rs.restaurant_id = pp.restaurant_id
	left join active_users au on rs.restaurant_id = au.restaurant_id
	order by rs.restaurant_name;
end;
$$ language plpgsql;

select * from get_statistic();

-- 10. Процедура добавления продукта
create or replace procedure add_product(
	product_name varchar(100),
	product_category_id uuid,
	price numeric(7, 2),
	restaurant_id uuid,
	photo_url text default null,
	rating numeric(3, 2) default 0,
	status text default 'Доступен',
	description text default null
) as $$
begin
	insert into product (product_name, product_category_id, price, restaurant_id, photo_url, rating, status, description)
	values (
		product_name, 
		product_category_id,
		price,
		restaurant_id, 
		photo_url, 
		rating, 
		status::product_status,
		description
	);
end;
$$ language plpgsql;

-- 11. Процедура для расчёта зарплаты курьера
create or replace procedure courier_salary() as $$
declare
	courier_rec record;
	order_count_var int;
	total_commission_var numeric(8, 2);
	current_rate_var numeric(2, 2);
	new_rate_var numeric(2, 2);
	payment_amount_var numeric(8, 2);

	calc_start_var timestamp := date_trunc('month', current_date - interval '1 month');
	calc_end_var   timestamp := date_trunc('month', current_date);
	year_var  int := extract(year from calc_start_var);
	month_var int := extract(month from calc_start_var);
	next_rate_date_var date := date_trunc('month', current_date)::date;
	
begin
	for courier_rec in 
		select courier_id from courier where dismissal_date is null
	loop
		select count(*), coalesce(sum(commission), 0)
		into order_count_var, total_commission_var
		from "order"
		where courier_id = courier_rec.courier_id and delivery_timestamp >= calc_start_var and delivery_timestamp <= calc_end_var and status = 'Завершен';

		select rate into current_rate_var
		from courier_rate
		where courier_id = courier_rec.courier_id and assignment_date <= calc_start_var::date
		order by assignment_date desc
		limit 1;

		if current_rate_var is null 
			then current_rate_var := 0.05; 
		end if;

		payment_amount_var := total_commission_var * current_rate_var;

		insert into courier_pay (year, month, courier_id, amount)
		values (year_var, month_var, courier_rec.courier_id, payment_amount_var)
		on conflict (year, month, courier_id) 
		do update set amount = excluded.amount;

		new_rate_var := case 
			when order_count_var between 0 and 100 then 0.05
			when order_count_var between 101 and 200 then 0.10
			when order_count_var between 201 and 300 then 0.20
			when order_count_var between 301 and 400 then 0.30
			when order_count_var between 401 and 500 then 0.40
			when order_count_var >= 501 then 0.50
			else 0.05
		end;

		insert into courier_rate (assignment_date, courier_id, rate)
		values (next_rate_date_var, courier_rec.courier_id, new_rate_var)
		on conflict (assignment_date, courier_id) 
		do update set rate = excluded.rate;

	end loop;
	raise notice 'Расчет за %-% выполнен.', month_var, year_var;
end;
$$ language plpgsql;

call courier_salary();

-- 12. Представление how_much_money
create or replace view how_much_money as
with recursive months_list as (
	select date_trunc('month', min(order_timestamp))::date as month
	from "order"
	union all
	select (month + interval '1 month')::date
	from months_list
	where month < (select date_trunc('month', max(order_timestamp))::date from "order")
),
order_statistics as (
	select 
		date_trunc('month', order_timestamp)::date as month,
		sum(order_amount) as sum_without_commission,
		sum(total_amount) as sum_with_commission,
		sum(commission) as total_commission
	from "order"
	where status = 'Завершен'
	group by 1
),
salary_statistics as (
	select 
		make_date(year, month, 1) as month,
		sum(amount) as courier_salary_total
	from courier_pay
	group by 1
)
select 
	to_char(m.month, 'yyyy-mm') as "Год и месяц",
	coalesce(os.sum_without_commission, 0) as "Сумма за месяц без комиссии",
	coalesce(os.sum_with_commission, 0) as "Сумма за месяц с комиссией",
	coalesce(os.total_commission, 0) as "Сумма комиссии",
	coalesce(os.total_commission + lag(os.total_commission) over (order by m.month), os.total_commission) as "Сумма комиссии за предыдущий месяц",
	coalesce(os.total_commission - lag(os.total_commission) over (order by m.month), 0) as "Разница в комиссии между текущим и предыдущим месяцем",
	coalesce(ps.courier_salary_total, 0) as "Размер оплаты курьерам",
	coalesce(os.total_commission - ps.courier_salary_total, 0) as "Чистая прибыль"
from months_list m
left join order_statistics os on m.month = os.month
left join salary_statistics ps on m.month = ps.month
order by m.month;

select * from how_much_money;