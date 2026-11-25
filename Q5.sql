CREATE TABLE members (member_id INT PRIMARY KEY AUTO_INCREMENT, member_number VARCHAR(20) NOT NULL UNIQUE, full_name VARCHAR(100) NOT NULL, fee_due DECIMAL(10,2) NOT NULL CHECK (fee_due > 0));
CREATE TABLE gym_payments (payment_id INT PRIMARY KEY AUTO_INCREMENT, member_id INT NOT NULL, amount DECIMAL(10,2) NOT NULL CHECK (amount > 0), paid_on DATE NOT NULL, FOREIGN KEY (member_id) REFERENCES members(member_id));
CREATE TABLE gym_audit (audit_id INT PRIMARY KEY AUTO_INCREMENT, payment_id INT NOT NULL, member_id INT NOT NULL, amount DECIMAL(10,2) NOT NULL, logged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (payment_id) REFERENCES gym_payments(payment_id), FOREIGN KEY (member_id) REFERENCES members(member_id));
CREATE TABLE daily_gym (collection_date DATE PRIMARY KEY, payment_count INT NOT NULL DEFAULT 0, total_amount DECIMAL(12,2) NOT NULL DEFAULT 0);
INSERT INTO members (member_number, full_name, fee_due) VALUES ('G001','Tina Mwansa', 1200.00), ('G002','Moses Banda', 900.00), ('G003','Faith Phiri', 1500.00);
DELIMITER //
CREATE FUNCTION fn_gym_balance(p_member_id INT) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN DECLARE v_fee DECIMAL(10,2); DECLARE v_paid DECIMAL(10,2); SELECT fee_due INTO v_fee FROM members WHERE member_id=p_member_id; IF v_fee IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown member'; END IF; SELECT COALESCE(SUM(amount),0) INTO v_paid FROM gym_payments WHERE member_id=p_member_id; RETURN v_fee - v_paid; END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE pr_gym_payment(IN p_member_id INT, IN p_amount DECIMAL(10,2), IN p_paid_on DATE) BEGIN DECLARE v_bal DECIMAL(10,2); IF p_member_id IS NULL OR p_amount IS NULL OR p_paid_on IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NULL not allowed'; END IF; IF p_amount <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Amount must be positive'; END IF; SET v_bal = fn_gym_balance(p_member_id); IF p_amount > v_bal THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment exceeds balance'; END IF; INSERT INTO gym_payments (member_id, amount, paid_on) VALUES (p_member_id, p_amount, p_paid_on); END //
DELIMITER ;
CALL pr_gym_payment(1,500.00,'2026-11-20'); CALL pr_gym_payment(1,300.00,'2026-11-21'); CALL pr_gym_payment(1,200.00,'2026-11-22'); CALL pr_gym_payment(2,400.00,'2026-11-20'); CALL pr_gym_payment(2,300.00,'2026-11-21'); CALL pr_gym_payment(2,200.00,'2026-11-22');
DELIMITER //
CREATE TRIGGER trg_gym_audit AFTER INSERT ON gym_payments FOR EACH ROW BEGIN INSERT INTO gym_audit (payment_id, member_id, amount, logged_at) VALUES (NEW.payment_id, NEW.member_id, NEW.amount, NOW()); END //
DELIMITER ;
CREATE VIEW v_gym_balances AS SELECT member_number, full_name, fn_gym_balance(member_id) AS outstanding_balance FROM members WHERE fn_gym_balance(member_id) > 0;
CREATE INDEX idx_gym_member_date ON gym_payments (member_id, paid_on);
EXPLAIN SELECT * FROM gym_payments WHERE member_id=1 AND paid_on BETWEEN '2026-11-20' AND '2026-11-22';
DELIMITER //
CREATE PROCEDURE pr_refresh_gym(IN p_day DATE) BEGIN INSERT INTO daily_gym (collection_date, payment_count, total_amount) SELECT p_day, COUNT(*), COALESCE(SUM(amount),0) FROM gym_payments WHERE paid_on=p_day ON DUPLICATE KEY UPDATE payment_count=VALUES(payment_count), total_amount=VALUES(total_amount); END //
DELIMITER ;
CREATE EVENT ev_refresh_gym ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR DO CALL pr_refresh_gym(CURDATE() - INTERVAL 1 DAY);
