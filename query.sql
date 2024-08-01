---------- TẠO BẢNG ----------
--Tạo bảng customers--
CREATE TABLE customers (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	age INTEGER CHECK (age >= 0), 
  	gender VARCHAR(10) CHECK (gender IN ('Nam', 'Nữ', 'Khác')),
	email VARCHAR(255) UNIQUE NOT NULL,
	phone VARCHAR(20) UNIQUE NOT NULL,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--Tạo bảng suppliers--
CREATE TABLE suppliers (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) UNIQUE NOT NULL,
	address VARCHAR(255),
	description TEXT,
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--Tạo bảng products--
CREATE TABLE products (
	id SERIAL PRIMARY KEY,
	name VARCHAR(255) NOT NULL,
	catalog VARCHAR(255),
	supplier_id INT REFERENCES suppliers(id),
	mgf TIMESTAMP,
	price MONEY NOT NULL,
	base_price MONEY NOT NULL,
	discount INTEGER DEFAULT 0,
	quantity INTEGER NOT NULL,
	description TEXT,
	image VARCHAR(255),
	created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
	updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

--Tạo bảng orders--
CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  customer_id INTEGER REFERENCES customers(id),
  product_id INTEGER REFERENCES products(id),
  address VARCHAR(255) DEFAULT 'Bach Khoa',
  quantity INTEGER NOT NULL,
  amount MONEY,
  status_payment SMALLINT CHECK (status_payment IN (0, 1, 2)), 
  status_shipment SMALLINT CHECK (status_shipment IN (0, 1, 2, 3)), 
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- TẠO VIEW, FUNCTION, TRIGGER --
--Tạo view về danh sách thông tin sản phẩm--
CREATE VIEW product_details AS
SELECT
  products.name AS product_name,
  products.price,
  products.discount,
  suppliers.name AS supplier_name,
  products.description
FROM products
INNER JOIN suppliers ON products.supplier_id = suppliers.id;
-- SELECT * FROM product_details;

--bảng thông tin về đơn hàng chưa thanh toán--
CREATE VIEW not_pending_orders AS
SELECT
  orders.id AS order_id,
  customers.name AS customer_name,
  products.name AS product_name,
  orders.quantity,
  orders.amount
FROM orders
INNER JOIN customers ON orders.customer_id = customers.id
INNER JOIN products ON orders.product_id = products.id
WHERE status_payment = 0;
-- SELECT * FROM not_pending_orders;

--bảng thông tin về đơn hàng đã thanh toán--
CREATE VIEW pending_orders AS
SELECT
  orders.id AS order_id,
  customers.name AS customer_name,
  products.name AS product_name,
  orders.quantity,
  orders.amount
FROM orders
INNER JOIN customers ON orders.customer_id = customers.id
INNER JOIN products ON orders.product_id = products.id
WHERE status_payment = 1;
-- SELECT * FROM pending_orders;

--Đưa ra xếp hạng các sản phẩm dựa vào số lượng bán ra--
CREATE OR REPLACE FUNCTION get_best_selling_products()
RETURNS TABLE (
    product_id INT,
    product_name VARCHAR(255),
    product_catalog VARCHAR(255),
    product_description TEXT,
    product_price MONEY,
    product_discount INT,
    product_amount MONEY,
    total_quantity_sold BIGINT,
    product_image VARCHAR(255)
)
AS $$
BEGIN
    RETURN QUERY
    WITH top_selling_products AS (
        SELECT
            o.product_id,
            SUM(o.quantity) AS total_quantity_sold,
            RANK() OVER (ORDER BY SUM(o.quantity) DESC) AS product_rank
        FROM
            orders o
        WHERE
            o.status_payment = 1
        GROUP BY
            o.product_id
    )
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        p.catalog AS product_catalog,
        p.description AS product_description,
        p.price AS product_price,
        p.discount AS product_discount,
        SUM(o.amount) AS product_amount,
        tsp.total_quantity_sold AS total_quantity_sold,
        p.image AS product_image
    FROM
        products p
        JOIN top_selling_products tsp ON p.id = tsp.product_id
		INNER JOIN orders o ON o.product_id = p.id
	GROUP BY o.product_id,p.id,tsp.total_quantity_sold
	ORDER BY tsp.total_quantity_sold DESC;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM get_best_selling_products();

--Tính tổng vốn phải bỏ ra cho 1 nhà cung cấp--
CREATE OR REPLACE FUNCTION get_total_base_price_by_supplier(supplier_name VARCHAR(255))
RETURNS TABLE(name VARCHAR(255), total_base_price MONEY)
AS $$
BEGIN
    RETURN QUERY
    SELECT s.name, SUM(p.base_price * o.quantity) AS total_base_price
    FROM orders o
    INNER JOIN products p ON o.product_id = p.id
    INNER JOIN suppliers s ON p.supplier_id = s.id
    WHERE s.name = get_total_base_price_by_supplier.supplier_name
          AND o.status_payment = 1
    GROUP BY s.name;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM get_total_base_price_by_supplier('Công ty Samsungelectronic');

--Tính doanh thu thu được từ 1 hãng--
CREATE OR REPLACE FUNCTION get_revenue_supplier(name_supplier VARCHAR(255))
RETURNS TABLE(supplier_name VARCHAR(255),total_revenue MONEY)
AS $$
BEGIN
	RETURN QUERY
	SELECT 
		s.name AS supplier_name,
		SUM(o.amount) AS total_revenue
	FROM products p
	INNER JOIN orders o ON o.product_id = p.id
	INNER JOIN suppliers s ON s.id = p.supplier_id
	WHERE name_supplier = s.name
	GROUP BY s.name;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM get_revenue_supplier('Công ty Samsungelectronic');

--Chèn thêm dữ liệu vào bảng products--
CREATE OR REPLACE FUNCTION update_data_products(
    p_name VARCHAR(255),
    p_catalog VARCHAR(255),
    p_mgf TIMESTAMP,
    p_supplier_name VARCHAR(255),
    p_price MONEY, 
    p_base_price MONEY,
    p_discount INT, 
    p_quantity INT,
    p_description TEXT,
    p_image VARCHAR(255)
)
RETURNS VARCHAR(50)
AS $$
DECLARE
    v_supplier_id INT; -- Khai báo biến v_supplier_id
BEGIN
    -- Kiểm tra xem nhà cung cấp có trong bảng suppliers chưa
    SELECT id INTO v_supplier_id
    FROM suppliers
    WHERE name = p_supplier_name;
    IF v_supplier_id IS NOT NULL THEN
        -- Nếu nhà cung cấp đã tồn tại, chỉ insert vào bảng products
        INSERT INTO products (name, catalog, mgf, price, base_price, discount, quantity, description, image, supplier_id)
        VALUES (p_name, p_catalog, p_mgf, p_price, p_base_price, p_discount, p_quantity, p_description, p_image, v_supplier_id);
		RETURN 'Success1';
    ELSE
        -- Nếu nhà cung cấp chưa tồn tại, insert vào bảng suppliers trước, sau đó insert vào bảng products
        INSERT INTO suppliers ( name)
        VALUES ( p_supplier_name);
		SELECT id INTO v_supplier_id
    	FROM suppliers
   		WHERE name = p_supplier_name;
        INSERT INTO products (name, catalog, mgf, price, base_price, discount, quantity, description, image, supplier_id)
        VALUES (p_name, p_catalog, p_mgf, p_price, p_base_price, p_discount, p_quantity, p_description, p_image, v_supplier_id);
		RETURN 'Success2';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- SELECT update_data_products(
--     'Samsung Galaxy Tab S6 Lite 2024',
--     'Tablet',
--     '2024-04-15',
--     'Samsung',
--     8990000::MONEY,
-- 	8400000::MONEY,
--     5,
--     25,
--     'Máy tính bảng mở ra không gian giải trí và làm việc đa năng',
--     'https://cdn.tgdd.vn/Products/Images/522/322134/Slider/vi-vn-samsung-galaxy-tab-s6-lite-2024-tong-quan-1.jpg'
-- );

--Tính thu nhập của cửa hàng theo tháng/quý/năm--
CREATE OR REPLACE FUNCTION get_store_revenue(start_date DATE,end_date DATE)
RETURNS TABLE (
    month INT,
    quarter INT,
    year INT,
    total_cost MONEY,
    total_revenue MONEY,
    total_profit MONEY
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(MONTH FROM o.created_at):: INT AS month,
        EXTRACT(QUARTER FROM o.created_at):: INT AS quarter,
        EXTRACT(YEAR FROM o.created_at):: INT AS year,
        SUM(o.quantity * p.base_price) AS total_cost,
        SUM(o.amount) AS total_revenue,
        SUM(o.amount - o.quantity*p.base_price) AS total_profit
    FROM orders o
        INNER JOIN products p ON o.product_id = p.id
    WHERE
        o.created_at BETWEEN start_date AND end_date AND o.status_payment = 1
    GROUP BY
        month,
        quarter,
        year
    ORDER BY
        year, quarter, month ASC;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM get_store_revenue('2024-01-01', '2024-12-31');

--Chèn dữ liệu vào bảng orders khi số điện thoại đã tồn tại--
CREATE OR REPLACE FUNCTION insert_order(
    o_phone VARCHAR(255),
    o_address VARCHAR(255),
    o_quantity INTEGER,
    o_product_id INTEGER,
    o_status_payment SMALLINT
)
RETURNS VARCHAR(20)
AS $$
DECLARE
    o_customer_id INTEGER;
	o_quantity_products INTEGER;
BEGIN
    -- Check if thide customer exists
    SELECT c.id INTO o_customer_id
    FROM customers c
    WHERE c.phone = o_phone;
	SELECT p.quantity INTO o_quantity_products
    FROM products p
    WHERE p.id = o_product_id; 
    IF o_customer_id IS NOT NULL THEN
		IF o_quantity <= o_quantity_products THEN
        	INSERT INTO orders (customer_id, product_id, address, quantity, status_payment,status_shipment)
        	VALUES (o_customer_id, o_product_id, o_address, o_quantity, o_status_payment,0);
        	RETURN 'Success';
		ELSE
			RETURN 'The quantity in the stock is not sufficient.';
		END IF;
    ELSE
        RETURN 'Fail';
    END IF;
END;
$$ LANGUAGE plpgsql;
-- SELECT insert_order(
--     '0985285439',
--     '17 Lê Thanh Nghị',
--     9,
--     8,
--     1:: SMALLINT
-- );

--Tìm 5 khách hàng mua nhiều nhất ở cửa hàng để tri ân--
CREATE FUNCTION get_top_customers(
    start_date DATE,
    end_date DATE,
    top_n INT DEFAULT 10
)
RETURNS TABLE (
    rank_by_spend BIGINT,
    customer_id INT,
    customer_name VARCHAR,
    customer_email VARCHAR(255),
    customer_phone VARCHAR(255),
    total_spend MONEY
)
AS $$
BEGIN
    RETURN QUERY
    WITH customer_spend AS (
        SELECT
            o.customer_id,
            SUM(o.amount) AS total_spend
        FROM orders o
        WHERE o.created_at BETWEEN start_date AND end_date AND o.status_payment = 1
        GROUP BY o.customer_id
    ),
    ranked_customers AS (
        SELECT
            cs.customer_id,
            cs.total_spend,
            RANK() OVER (ORDER BY cs.total_spend DESC) AS rank_by_spend
        FROM customer_spend cs
    )
    SELECT
        rc.rank_by_spend,
        rc.customer_id,
        c.name AS customer_name,
        c.email AS customer_email,
        c.phone AS customer_phone,
        rc.total_spend
    FROM ranked_customers rc
    INNER JOIN customers c ON c.id = rc.customer_id
    WHERE rc.rank_by_spend <= top_n
    ORDER BY rc.rank_by_spend ASC;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM get_top_customers('2024-02-01', '2024-06-11', 5);

--Tìm kiếm thông tin sản phẩm--
CREATE OR REPLACE FUNCTION search_inf_products(p_catalog VARCHAR(255), max_price MONEY, min_price MONEY)
RETURNS TABLE (
    product_id INT,
    product_name VARCHAR(255),
    product_catalog VARCHAR(255),
	product_supplier VARCHAR(255),
    product_description TEXT,
    product_price MONEY,
    product_discount INT,
    product_image VARCHAR(255)
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.id AS product_id,
        p.name AS product_name,
        p.catalog AS product_catalog,
		s.name AS product_supplier,
        p.description AS product_description,
        p.price AS product_price,
        p.discount AS product_discount,
        p.image AS product_image
    FROM products p
	INNER JOIN suppliers s ON s.id = p.supplier_id
	WHERE p.catalog = search_inf_products.p_catalog 
		  AND p.price <= search_inf_products.max_price AND p.price >= search_inf_products.min_price;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM search_inf_products('Phụ kiện'::VARCHAR(255), 10000000::MONEY, 500000::MONEY);

--Xuất ra bảng xếp hạng của các hãng được quan tâm-- 
CREATE OR REPLACE FUNCTION rank_of_suppliers()
RETURNS TABLE (supplier_name VARCHAR(255), total_quantity_sold INT, rank_num BIGINT)
AS $$
BEGIN
	RETURN QUERY
	WITH number_of_purchases AS(
	SELECT
		s.id AS supplier_id,
		s.name AS supplier_name,
		SUM(o.quantity) :: INT AS total_quantity_sold
	FROM products p
	INNER JOIN suppliers s ON s.id = p.supplier_id
	INNER JOIN orders o ON o.product_id = p.id
	WHERE o.status_payment = 1
	GROUP BY s.id
	)
	SELECT
		number_of_purchases.supplier_name,
		number_of_purchases.total_quantity_sold,
		RANK() OVER (ORDER BY number_of_purchases.total_quantity_sold DESC) AS rank_num
	FROM number_of_purchases;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM rank_of_suppliers();



--Tính toán lợi nhuận thu được của 1 sản phẩm-- 
CREATE OR REPLACE FUNCTION get_product_profit(product_name VARCHAR(255))
RETURNS MONEY
AS $$
  DECLARE total_revenue MONEY;
  DECLARE total_cost MONEY;
  DECLARE profit MONEY;
BEGIN
  SELECT SUM(o.quantity * p.base_price) INTO total_cost
  FROM orders o
  INNER JOIN products p ON o.product_id = p.id
  WHERE p.name = product_name AND o.status_payment = 1;
  SELECT SUM(o.amount) INTO total_revenue
  FROM orders o
  INNER JOIN products p ON o.product_id = p.id
  WHERE p.name = product_name AND o.status_payment = 1;
  profit := total_revenue - total_cost;
  RETURN profit;
END;
$$ LANGUAGE plpgsql;
-- SELECT * FROM get_product_profit('Pin sạc dự phòng 10000mAh');

--Tự cập nhật giá phải thanh toán cho khách hàng--
CREATE OR REPLACE FUNCTION update_order_amount()
RETURNS TRIGGER AS $$
DECLARE
    product_price NUMERIC;
    product_discount NUMERIC;
BEGIN
    -- Lấy thông tin sản phẩm từ bảng products
    SELECT p.price, p.discount 
    INTO product_price, product_discount
    FROM products p
    WHERE p.id = NEW.product_id;
    NEW.amount := NEW.quantity * product_price * (1 - product_discount / 100.0);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_order_amount
BEFORE INSERT OR UPDATE ON orders
FOR EACH ROW
EXECUTE PROCEDURE update_order_amount();

--Cập nhật lại số lượng hàng trong kho sau khi hàng đã thanh toán--
CREATE OR REPLACE FUNCTION update_product_quantity()
RETURNS TRIGGER AS $$
DECLARE
    product_id INT;
    order_quantity INT;
BEGIN
    product_id := NEW.product_id;
    order_quantity := NEW.quantity;
    UPDATE products
    SET quantity = quantity - order_quantity
    WHERE id = product_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER update_product_quantity
AFTER INSERT OR UPDATE ON orders
FOR EACH ROW
WHEN (NEW.status_payment = 1)
EXECUTE PROCEDURE update_product_quantity();

--Tự động cập nhật update_at theo thời gian thực--
--Bảng suppliers--
CREATE OR REPLACE FUNCTION auto_update_updated_at_suppliers()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.* IS DISTINCT FROM OLD.* THEN
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_updated_at_trigger_suppliers
BEFORE UPDATE ON suppliers
FOR EACH ROW
EXECUTE FUNCTION auto_update_updated_at_suppliers();

--Bảng customers--
CREATE OR REPLACE FUNCTION auto_update_updated_at_customers()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.* IS DISTINCT FROM OLD.* THEN
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_updated_at_trigger_customers
BEFORE UPDATE ON customers
FOR EACH ROW
EXECUTE FUNCTION auto_update_updated_at_customers();

--Bảng products--
CREATE OR REPLACE FUNCTION auto_update_updated_at_products()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.* IS DISTINCT FROM OLD.* THEN
        NEW.updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER update_updated_at_trigger_products
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION auto_update_updated_at_products();


--  CHÈN DỮ LIỆU VÀO BẢNG --
--Bảng customers--
INSERT INTO customers (name, age, gender, email, phone)
VALUES
('Nguyễn Văn An', 28, 'Nam', 'nguyenvanan@gmail.com', '0985285432'),
('Trần Thị Bình', 35, 'Nữ', 'tranthibinh@gmail.com', '0987654321'),
('Lê Hoàng Dương', 22, 'Nam', 'lhduong@gmail.com', '0555123456'),
('Phạm Thu Hà', 27, 'Nữ', 'phamthuha@gmail.com', '0521876543'),
('Ngô Minh Khoa', 30, 'Nam', 'ngominhkhoa@gmail.com', '0989456123'),
('Đỗ Thị Lan', 29, 'Nữ', 'dothuilan@gmail.com', '0987654123'),
('Vũ Hoàng Anh', 24, 'Nam', 'vuhoanganh@gmail.com', '0981654987'),
('Lê Thị Hồng', 32, 'Nữ', 'lethihong@gmail.com', '0986789123'),
('Trần Văn Hải', 31, 'Nam', 'tranvanhai@gmail.com', '0989123456'),
('Nguyễn Thị Hoa', 26, 'Nữ', 'nguyenthihoa@gmail.com', '0983456789'),
('Phạm Minh Đức', 28, 'Nam', 'phamminduc@gmail.com', '0987123456'),
('Trịnh Thị Thanh', 33, 'Nữ', 'trinhtithanh@gmail.com', '0986321987'),
('Lê Văn Sơn', 25, 'Nam', 'levinson@gmail.com', '0989654123'),
('Nguyễn Thị Hải', 30, 'Nữ', 'nguyenthihai@gmail.com', '0523789456'),
('Đoàn Minh Tuấn', 27, 'Nam', 'dminhtuan@gmail.com', '0986123789');

--Bảng suppliers--
INSERT INTO suppliers (name, address, description)
VALUES
('Công ty Samsungelectronic', '123 Đường ABC, Hà Nội', 'Nhà sản xuất điện thoại hàng đầu Việt Nam'),
('Cty XYZ Supplies', '456 Đường XYZ, TP.HCM', 'Nhà cung cấp phụ kiện điện thoại uy tín'),
('Công ty Acme', '789 Đường Acme, Đà Nẵng', 'Nhà sản xuất linh kiện điện thoại chất lượng cao'),
('Samsung Việt Nam', '456 Đường Lê Văn Lương, Hà Nội', 'Công ty con của Samsung chuyên sản xuất các sản phẩm điện tử'),
('Samsung Display', '789 Đường Võ Văn Ngân, TP.HCM', 'Nhà cung cấp màn hình OLED và LCD chất lượng cao cho smartphone Samsung'),
('Samsung SDI', '321 Đường Trường Chinh, Đà Nẵng', 'Nhà sản xuất pin và linh kiện điện tử cho các sản phẩm của Samsung'),
('Samsung Electro-Mechanics', '159 Đường Bà Triệu, Hải Phòng', 'Nhà cung cấp các linh kiện điện tử cho các sản phẩm của Samsung'),
('Samsung Electronics HCMC CE Complex', '753 Đường Võ Thị Sáu, TP.HCM', 'Nhà máy cung cấp các sản phẩm điện tử tiêu dùng của Samsung tại Việt Nam'),
('Samsung Electronics Bắc Ninh', '357 Đường Đại Lộ Hà Nội, Bắc Ninh', 'Nhà máy cung cấp linh kiện và sản phẩm điện tử của Samsung tại Bắc Ninh'),
('Samsung Việt Nam R&D Center', '159 Đường Trần Phú, Hà Nội', 'Trung tâm nghiên cứu và phát triển các sản phẩm mới của Samsung tại Việt Nam'),
('Samsung Việt Nam Logistics', '753 Đường Cộng Hòa, TP.HCM', 'Công ty phụ trách về logistics và cung ứng các sản phẩm của Samsung tại Việt Nam'),
('Samsung Việt Nam IT', '357 Đường Lê Duẩn, Hà Nội', 'Công ty cung cấp các dịch vụ CNTT và viễn thông cho các công ty thuộc Samsung tại Việt Nam'),
('Samsung Việt Nam Component', '159 Đường Trường Sơn, Đà Nẵng', 'Nhà cung cấp các linh kiện và phụ kiện cho các sản phẩm của Samsung tại Việt Nam');

--Bảng products--
INSERT INTO products (name, catalog, supplier_id, mgf, price, base_price, discount, quantity, description, image)
VALUES
('Samsung Galaxy S24 Ultra', 'Điện thoại', 1, '2023-04-15', 34000000, 25000000, 20, 100, 'Điện thoại thông minh thế hệ mới', 'https://cdn2.cellphones.com.vn/insecure/rs:fill:358:358/q:90/plain/https://cellphones.com.vn/media/catalog/product/s/s/ss-s24-ultra-xam-222.png'),
('Tai nghe bluetooth', 'Phụ kiện', 2, '2023-03-01', 5000000, 2500000, 45, 50, 'Phụ kiện tai nghe cho điện thoại', 'https://cdn2.cellphones.com.vn/insecure/rs:fill:358:358/q:90/plain/https://cellphones.com.vn/media/catalog/product/s/a/samsung-galaxy-buds-2-pro-00.png'),
('Samsung Galaxy Tab A9', 'Máy tính bảng', 12, '2023-05-20', 4000000, 3200000, 15, 75, 'Máy tính bảng thế hệ mới', 'https://cdn2.cellphones.com.vn/insecure/rs:fill:358:358/q:90/plain/https://cellphones.com.vn/media/catalog/product/s/a/samsung-galaxy-tab-a9_10_.png'),
('Samsung Galaxy Watch4', 'Đồng hồ thông minh', 13, '2023-02-10', 4000000,3000000, 20, 25, 'Đồng hồ thông minh thế hệ mới', 'https://cdn2.cellphones.com.vn/insecure/rs:fill:358:358/q:90/plain/https://cellphones.com.vn/media/catalog/product/s/a/sansung_5_.png'),
('Smart Tivi Samsung', 'Tivi', 5, '2023-06-01', 19000000, 10500000, 40, 150, 'Tivi thông minh cho gia đình', 'https://cdn2.cellphones.com.vn/insecure/rs:fill:358:358/q:90/plain/https://cellphones.com.vn/media/catalog/product/u/a/ua50au7002_1_.png'),
('Adapter Sạc Type C', 'Phụ kiện', 9, '2023-06-20', 490000, 350000, 25, 20, 'Củ sạc tích hợp sạc nhanh', 'https://cdn.tgdd.vn/Products/Images/9499/234361/type-c-pd-25w-samsung-ep-ta800nw-trang-1-org.jpg'),
('Pin sạc dự phòng 10000mAh', 'Phụ kiện', 6, '2023-05-20', 1150000, 900000, 20, 40, 'Sạc dự phong công suất cao', 'https://cdn.tgdd.vn/Products/Images/57/326108/pin-sac-du-phong-10000mah-khong-day-type-c-pd-25w-samsung-eb-u2510-1.jpg'),
('Loa Thanh Samsung HW-B650D', 'Phụ kiện', 11, '2022-06-20', 6900000, 6000000, 10, 25, 'Loa âm thanh chất lượng cao', 'https://cdn.tgdd.vn/Products/Images/2162/322712/loa-thanh-samsung-hw-b650d-xv-370w-1.jpg'),
('Samsung Galaxy Fit3', 'Smartwatch', 13, '2022-07-19', 1390000, 950000, 30, 15, 'Đồng hồ thông minh thế hệ mới', 'https://cdn.tgdd.vn/Products/Images/7077/321616/samsung-galaxy-fit3-den-hc-1.jpg'),
('Samsung Galaxy A55 5G', 'Điện thoại', 1, '2024-04-20', 12000000, 11000000, 5, 20, 'Điện thoại thông minh 5G', 'https://cdn.tgdd.vn/Products/Images/42/322096/samsung-galaxy-a55-5g-xanh-1-1.jpg'),
('Adapter Sạc Type C', 'Phụ kiện', 2, '2023-06-20', 490000, 350000, 25, 20, 'Củ sạc tích hợp sạc nhanh', 'https://cdn.tgdd.vn/Products/Images/9499/234361/type-c-pd-25w-samsung-ep-ta800nw-trang-1-org.jpg');

--Bảng orders—
INSERT INTO orders (customer_id, product_id, address, quantity, status_payment, status_shipment)
VALUES
(13, 3, '78 Hoàng Cầu', 1, 1, 2),
(5, 4, '45 Ngô Gia Tự', 2, 0, 1),
(2, 5, '199 Bạch Mai', 1, 1, 3),
(3, 6, '87 Lê Thanh Nghị', 1, 1, 2),
(1, 7, '15 Tạ Quang Bửu', 2, 1, 1),
(4, 8, '78 Hoàng Cầu', 1, 0, 0),
(5, 9, '45 Ngô Gia Tự', 1, 1, 2),
(14, 10, '199 Bạch Mai', 1, 0, 1),
(3, 1, '87 Lê Thanh Nghị', 1, 1, 3),
(1, 2, '15 Tạ Quang Bửu', 1, 1, 2),
(4, 3, '78 Hoàng Cầu', 2, 1, 1),
(5, 4, '45 Ngô Gia Tự', 1, 0, 0),
(11, 5, '199 Bạch Mai', 1, 1, 2),
(3, 6, '87 Lê Thanh Nghị', 1, 1, 3),
(1, 7, '15 Tạ Quang Bửu', 1, 0, 1),
(4, 8, '78 Hoàng Cầu', 2, 1, 2),
(12, 9, '45 Ngô Gia Tự', 1, 1, 1),
(2, 10, '199 Bạch Mai', 1, 0, 0),
(3, 1, '87 Lê Thanh Nghị', 1, 1, 2),
(13, 2, '15 Tạ Quang Bửu', 1, 1, 3);
