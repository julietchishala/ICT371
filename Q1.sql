CREATE TABLE medicines (medicine_id INT PRIMARY KEY AUTO_INCREMENT, medicine_name VARCHAR(100) NOT NULL UNIQUE, unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0), stock_qty INT NOT NULL CHECK (stock_qty >= 0));
CREATE TABLE sales (sale_id INT PRIMARY KEY AUTO_INCREMENT, medicine_id INT NOT NULL, quantity INT NOT NULL CHECK (quantity > 0), unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0), sold_on DATE NOT NULL, FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id));
CREATE TABLE stock_audit (audit_id INT PRIMARY KEY AUTO_INCREMENT, medicine_id INT NOT NULL, old_qty INT NOT NULL, new_qty INT NOT NULL, changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (medicine_id) REFERENCES medicines(medicine_id));
CREATE TABLE daily_sales (sales_date DATE PRIMARY KEY, total_qty INT NOT NULL DEFAULT 0, total_amount DECIMAL(12,2) NOT NULL DEFAULT 0);
INSERT INTO medicines (medicine_name, unit_price, stock_qty) VALUES ('Paracetamol 500mg', 5.00, 100), ('Amoxicillin 250mg', 12.50, 50), ('Ibuprofen 200mg', 8.00, 80);
DELIMITER //
CREATE FUNCTION fn_sale_value(p_medicine_id INT, p_quantity INT) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN DECLARE v_price DECIMAL(10,2); IF p_quantity IS NULL OR p_quantity <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantity must be positive'; END IF; SELECT unit_price INTO v_price FROM medicines WHERE medicine_id=p_medicine_id; IF v_price IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown medicine'; END IF; RETURN v_price * p_quantity; END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE pr_record_sale(IN p_medicine_id INT, IN p_quantity INT, IN p_sold_on DATE) BEGIN DECLARE v_stock INT; DECLARE v_price DECIMAL(10,2); IF p_medicine_id IS NULL OR p_quantity IS NULL OR p_sold_on IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NULL not allowed'; END IF; IF p_quantity <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantity must be positive'; END IF; SELECT stock_qty, unit_price INTO v_stock, v_price FROM medicines WHERE medicine_id=p_medicine_id; IF v_stock IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown medicine'; END IF; IF p_quantity > v_stock THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Insufficient stock'; END IF; INSERT INTO sales (medicine_id, quantity, unit_price, sold_on) VALUES (p_medicine_id, p_quantity, v_price, p_sold_on); UPDATE medicines SET stock_qty=stock_qty-p_quantity WHERE medicine_id=p_medicine_id; END //
DELIMITER ;
CALL pr_record_sale(1,10,'2026-11-24'); CALL pr_record_sale(1,5,'2026-11-24'); CALL pr_record_sale(2,4,'2026-11-24'); CALL pr_record_sale(3,6,'2026-11-24'); CALL pr_record_sale(2,2,'2026-11-23'); CALL pr_record_sale(3,10,'2026-11-23');
DELIMITER //
CREATE TRIGGER trg_medicines_stock_audit AFTER UPDATE ON medicines FOR EACH ROW BEGIN IF OLD.stock_qty <> NEW.stock_qty THEN INSERT INTO stock_audit (medicine_id, old_qty, new_qty, changed_at) VALUES (NEW.medicine_id, OLD.stock_qty, NEW.stock_qty, NOW()); END IF; END //
DELIMITER ;
CREATE VIEW v_low_stock AS SELECT medicine_name, unit_price, stock_qty AS remaining_stock FROM medicines WHERE stock_qty < 10;
CREATE INDEX idx_sales_medicine_date ON sales (medicine_id, sold_on);
EXPLAIN SELECT * FROM sales WHERE medicine_id=1 AND sold_on BETWEEN '2026-11-23' AND '2026-11-24';
DELIMITER //
CREATE PROCEDURE pr_refresh_sales(IN p_day DATE) BEGIN INSERT INTO daily_sales (sales_date, total_qty, total_amount) SELECT p_day, COALESCE(SUM(quantity),0), COALESCE(SUM(quantity*unit_price),0) FROM sales WHERE sold_on=p_day ON DUPLICATE KEY UPDATE total_qty=VALUES(total_qty), total_amount=VALUES(total_amount); END //
DELIMITER ;
CREATE EVENT ev_refresh_sales ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 15 MINUTE DO CALL pr_refresh_sales(CURDATE() - INTERVAL 1 DAY);
