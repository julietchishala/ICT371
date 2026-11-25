CREATE TABLE products (product_id INT PRIMARY KEY AUTO_INCREMENT, product_name VARCHAR(100) NOT NULL UNIQUE, unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0), stock_qty INT NOT NULL CHECK (stock_qty >= 0));
CREATE TABLE store_sales (sale_id INT PRIMARY KEY AUTO_INCREMENT, product_id INT NOT NULL, quantity INT NOT NULL CHECK (quantity > 0), unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0), sold_on DATE NOT NULL, FOREIGN KEY (product_id) REFERENCES products(product_id));
CREATE TABLE store_audit (audit_id INT PRIMARY KEY AUTO_INCREMENT, product_id INT NOT NULL, old_qty INT NOT NULL, new_qty INT NOT NULL, changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (product_id) REFERENCES products(product_id));
CREATE TABLE daily_store (sales_date DATE PRIMARY KEY, total_qty INT NOT NULL DEFAULT 0, total_amount DECIMAL(12,2) NOT NULL DEFAULT 0);
INSERT INTO products (product_name, unit_price, stock_qty) VALUES ('Sugar 2kg', 35.00, 60), ('Cooking Oil 2L', 85.00, 40), ('Rice 5kg', 120.00, 30);
DELIMITER //
CREATE FUNCTION fn_store_value(p_product_id INT, p_quantity INT) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN DECLARE v_price DECIMAL(10,2); IF p_quantity IS NULL OR p_quantity <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantity must be positive'; END IF; SELECT unit_price INTO v_price FROM products WHERE product_id=p_product_id; IF v_price IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown product'; END IF; RETURN v_price * p_quantity; END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE pr_store_sale(IN p_product_id INT, IN p_quantity INT, IN p_sold_on DATE) BEGIN DECLARE v_stock INT; DECLARE v_price DECIMAL(10,2); IF p_product_id IS NULL OR p_quantity IS NULL OR p_sold_on IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NULL not allowed'; END IF; IF p_quantity <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantity must be positive'; END IF; SELECT stock_qty, unit_price INTO v_stock, v_price FROM products WHERE product_id=p_product_id; IF v_stock IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown product'; END IF; IF p_quantity > v_stock THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Insufficient stock'; END IF; INSERT INTO store_sales (product_id, quantity, unit_price, sold_on) VALUES (p_product_id, p_quantity, v_price, p_sold_on); UPDATE products SET stock_qty=stock_qty-p_quantity WHERE product_id=p_product_id; END //
DELIMITER ;
CALL pr_store_sale(1,5,'2026-11-20'); CALL pr_store_sale(1,3,'2026-11-20'); CALL pr_store_sale(2,2,'2026-11-21'); CALL pr_store_sale(3,1,'2026-11-21'); CALL pr_store_sale(2,4,'2026-11-22'); CALL pr_store_sale(3,2,'2026-11-22');
DELIMITER //
CREATE TRIGGER trg_store_audit AFTER UPDATE ON products FOR EACH ROW BEGIN IF OLD.stock_qty <> NEW.stock_qty THEN INSERT INTO store_audit (product_id, old_qty, new_qty, changed_at) VALUES (NEW.product_id, OLD.stock_qty, NEW.stock_qty, NOW()); END IF; END //
DELIMITER ;
CREATE VIEW v_store_low_stock AS SELECT product_name, unit_price, stock_qty AS remaining_stock FROM products WHERE stock_qty < 10;
CREATE INDEX idx_store_product_date ON store_sales (product_id, sold_on);
EXPLAIN SELECT * FROM store_sales WHERE product_id=1 AND sold_on BETWEEN '2026-11-20' AND '2026-11-22';
DELIMITER //
CREATE PROCEDURE pr_refresh_store(IN p_day DATE) BEGIN INSERT INTO daily_store (sales_date, total_qty, total_amount) SELECT p_day, COALESCE(SUM(quantity),0), COALESCE(SUM(quantity*unit_price),0) FROM store_sales WHERE sold_on=p_day ON DUPLICATE KEY UPDATE total_qty=VALUES(total_qty), total_amount=VALUES(total_amount); END //
DELIMITER ;
CREATE EVENT ev_refresh_store ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR DO CALL pr_refresh_store(CURDATE() - INTERVAL 1 DAY);
