CREATE TABLE Students (student_id INT PRIMARY KEY AUTO_INCREMENT, student_number VARCHAR(20) NOT NULL UNIQUE, full_name VARCHAR(100) NOT NULL, fee_due DECIMAL(10,2) NOT NULL CHECK (fee_due > 0));
CREATE TABLE Payments (payment_id INT PRIMARY KEY AUTO_INCREMENT, student_id INT NOT NULL, amount DECIMAL(10,2) NOT NULL CHECK (amount > 0), paid_on DATE NOT NULL, FOREIGN KEY (student_id) REFERENCES Students(student_id));
CREATE TABLE payment_audit (audit_id INT PRIMARY KEY AUTO_INCREMENT, payment_id INT NOT NULL, student_id INT NOT NULL, amount DECIMAL(10,2) NOT NULL, logged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (payment_id) REFERENCES Payments(payment_id), FOREIGN KEY (student_id) REFERENCES Students(student_id));
CREATE TABLE daily_collections (collection_date DATE PRIMARY KEY, payment_count INT NOT NULL DEFAULT 0, total_amount DECIMAL(12,2) NOT NULL DEFAULT 0);
INSERT INTO Students (student_number, full_name, fee_due) VALUES ('2024-001','Chanda Mwansa',5000.00), ('2024-002','Grace Banda',3500.00), ('2024-003','Kelvin Phiri',4200.00);
DELIMITER //
CREATE FUNCTION fn_fee_balance(p_student_id INT) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN DECLARE v_fee DECIMAL(10,2); DECLARE v_paid DECIMAL(10,2); SELECT fee_due INTO v_fee FROM Students WHERE student_id=p_student_id; IF v_fee IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown student'; END IF; SELECT COALESCE(SUM(amount),0) INTO v_paid FROM Payments WHERE student_id=p_student_id; RETURN v_fee - v_paid; END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE pr_receive_payment(IN p_student_id INT, IN p_amount DECIMAL(10,2), IN p_paid_on DATE) BEGIN DECLARE v_balance DECIMAL(10,2); IF p_student_id IS NULL OR p_amount IS NULL OR p_paid_on IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NULL not allowed'; END IF; IF p_amount <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Amount must be greater than zero'; END IF; SET v_balance = fn_fee_balance(p_student_id); IF p_amount > v_balance THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Payment exceeds outstanding balance'; END IF; INSERT INTO Payments (student_id, amount, paid_on) VALUES (p_student_id, p_amount, p_paid_on); END //
DELIMITER ;
CALL pr_receive_payment(1,1000.00,'2026-11-20'); CALL pr_receive_payment(1,1500.00,'2026-11-21'); CALL pr_receive_payment(1,500.00,'2026-11-22'); CALL pr_receive_payment(2,1000.00,'2026-11-20'); CALL pr_receive_payment(2,500.00,'2026-11-21'); CALL pr_receive_payment(2,1000.00,'2026-11-22');
DELIMITER //
CREATE TRIGGER trg_payment_audit AFTER INSERT ON Payments FOR EACH ROW BEGIN INSERT INTO payment_audit (payment_id, student_id, amount, logged_at) VALUES (NEW.payment_id, NEW.student_id, NEW.amount, NOW()); END //
DELIMITER ;
CREATE VIEW v_fee_balances AS SELECT s.student_number, s.full_name, fn_fee_balance(s.student_id) AS outstanding_balance FROM Students s WHERE fn_fee_balance(s.student_id) > 0;
CREATE INDEX idx_payments_student_date ON Payments (student_id, paid_on);
EXPLAIN SELECT * FROM Payments WHERE student_id=1 AND paid_on BETWEEN '2026-11-20' AND '2026-11-22';
DELIMITER //
CREATE PROCEDURE pr_refresh_collections(IN p_day DATE) BEGIN INSERT INTO daily_collections (collection_date, payment_count, total_amount) SELECT p_day, COUNT(*), COALESCE(SUM(amount),0) FROM Payments WHERE paid_on=p_day ON DUPLICATE KEY UPDATE payment_count=VALUES(payment_count), total_amount=VALUES(total_amount); END //
DELIMITER ;
CREATE EVENT ev_refresh_collections ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR DO CALL pr_refresh_collections(CURDATE() - INTERVAL 1 DAY);
