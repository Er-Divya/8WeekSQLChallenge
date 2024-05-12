-- 1. What is the total amount each customer spent at the restaurant?
Select 
	s.customer_id, 
	sum(m.price) from Sales as s
left join 
	menu as m 
on 
	s.product_id = m.product_id
group by 
	s.customer_id;

-- 2. How many days has each customer visited the restaurant?

Select 
	customer_id, 
	count(distinct order_date) as number_of_visits
from 
	sales
group by 
	customer_id;

-- 3. What was the first item from the menu purchased by each customer?

Select 
	temp.customer_id, 
	temp.product_id, 
    m.product_name 
from 
	(
		Select 
			*, 
            row_number() over(partition by customer_id order by order_date asc) as row_num 
		from 
			sales
	) as temp
Join 
	menu as m
On 
	m.product_id = temp.product_id
where 
	row_num = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?


Select 
	m.product_name, 
	count(s.product_id) as total_sale 
from 
	sales as s 
join 
	menu as m On m.product_id = s.product_id
group by 
	m.product_name 
order by 
	total_sale desc 
Limit 1;

-- 5. Which item was the most popular for each customer?

with new_t as 
(
	Select 
		customer_id, 
        product_id, 
        count(product_id) as quantity_brought,
		dense_rank() over(partition by customer_id order by count(product_id) desc) as dense_partition
	from 
		sales
	group by 
		customer_id, product_id
);

Select 
	t.customer_id, 
    m.product_name
from 
	new_t as t
join 
	menu as m On m.product_id = t.product_id
where 
	t.dense_partition = 1
order by 
	t.customer_id;

-- 6. Which item was purchased first by the customer after they became a member?

with new_t as 
	(
		Select 
			s.*, 
            row_number() over(partition by customer_id order by order_date asc) as row_num
		from 
			sales as s
		Join
			members as m On s.customer_id = m.customer_id
		where 
			s.order_date >= m.join_date
	)

Select 
	t.customer_id, 
    m.product_name
from 
	new_t as t
Join 
	menu as m on t.product_id = m.product_id
where 
	t.row_num = 1
order by 
	t.customer_id;

-- 7. Which item was purchased just before the customer became a member?
with new_t as 
	(
		Select 
			s.*, 
			dense_rank() over(partition by customer_id order by order_date desc) as row_num
		from 
			sales as s
		Join 
			members as m On s.customer_id = m.customer_id
		where 
			s.order_date < m.join_date
	)

Select 
	t.customer_id, 
	m.product_name
from 
	new_t as t
Join 
	menu as m on t.product_id = m.product_id
where 
	t.row_num = 1
order by 
	t.customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
-- Constraint: Before they became member
-- a. How many items each customer bought?
-- b. How much does overall each customer spent on these items? 

Select 
	s.customer_id, 
	count(s.product_id) as products_count, 
	sum(m.price) as total_price
from 
	sales as s
Join 
	members as mem On mem.customer_id = s.customer_id
Join 
	menu as m On m.product_id = s.product_id
where 
	s.order_date < mem.join_date
group by 
	s.customer_id;

-- 9. For each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- For sushi, price is multiplied by 20, for rest of the products price is multiplied by 10 to calculate points

Select 
	s.customer_id, 
	sum(
		Case when trim(lower(m.product_name)) = 'sushi' then m.price * 20
		Else m.price * 10
		End
    ) as total_points
from 
	sales as s
Join 
	menu as m on m.product_id = s.product_id
group by 
	s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all 
--     items, not just sushi - how many points do customer A and B have at the end of January?
-- a. For order before join date on all products, except sushi, points are equal to price * 10
-- b. After join date for first week, points are equal to price * 20 except 
-- c. For sushi, points are always price * 20
-- d. Consider order date before '2021-01-31'

with dates as 
(
	Select 
		*, 
		date_add(join_date, interval +6 day) as week_date 
	from 
		members
)

Select 
	s.customer_id, 
	sum(
	Case when trim(lower(m.product_name)) = 'sushi' then m.price * 20
	When s.order_date between d.join_date and d.week_date then m.price * 20
	Else m.price*10
	End
	) as total_points
from 
	dates as d
Join 
	sales as s On s.customer_id = d.customer_id
Join 
	menu as m On s.product_id = m.product_id
where 
	s.order_date <= '2021-01-31'
group by 
	s.customer_id;

-- 11. Join all the tables to show customer_id, order_date, product_name, price and their membership status on that day
SELECT 
	s.customer_id, 
	s.order_date, 
	m.product_name, 
	m.price, 
	CASE 
		WHEN s.order_date >= mem.join_date THEN 'Y'
		ELSE 'N'
	END AS should_rank
FROM 
	sales AS s
JOIN 
	menu AS m ON s.product_id = m.product_id
LEFT JOIN 
	members AS mem ON mem.customer_id = s.customer_id
