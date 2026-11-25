CREATE TABLE books (book_id INT PRIMARY KEY AUTO_INCREMENT, title VARCHAR(150) NOT NULL UNIQUE, copies_available INT NOT NULL CHECK (copies_available >= 0), fine_per_day DECIMAL(10,2) NOT NULL CHECK (fine_per_day >= 0));
CREATE TABLE members (member_id INT PRIMARY KEY AUTO_INCREMENT, member_number VARCHAR(20) NOT NULL UNIQUE, full_name VARCHAR(100) NOT NULL);
CREATE TABLE loans (loan_id INT PRIMARY KEY AUTO_INCREMENT, book_id INT NOT NULL, member_id INT NOT NULL, quantity INT NOT NULL CHECK (quantity > 0), loaned_on DATE NOT NULL, FOREIGN KEY (book_id) REFERENCES books(book_id), FOREIGN KEY (member_id) REFERENCES members(member_id));
CREATE TABLE loan_audit (audit_id INT PRIMARY KEY AUTO_INCREMENT, book_id INT NOT NULL, old_qty INT NOT NULL, new_qty INT NOT NULL, changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (book_id) REFERENCES books(book_id));
CREATE TABLE daily_loans (loan_date DATE PRIMARY KEY, total_qty INT NOT NULL DEFAULT 0, total_loans INT NOT NULL DEFAULT 0);
INSERT INTO books (title, copies_available, fine_per_day) VALUES ('Database Systems', 10, 2.00), ('Python Programming', 8, 1.50), ('Data Structures', 12, 2.50);
INSERT INTO members (member_number, full_name) VALUES ('M001','Mutinta Zulu'), ('M002','Boyd Chanda'), ('M003','Natasha Phiri');
DELIMITER //
CREATE FUNCTION fn_loan_value(p_book_id INT, p_quantity INT) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN DECLARE v_fine DECIMAL(10,2); IF p_quantity IS NULL OR p_quantity <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantity must be positive'; END IF; SELECT fine_per_day INTO v_fine FROM books WHERE book_id=p_book_id; IF v_fine IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown book'; END IF; RETURN v_fine * p_quantity; END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE pr_record_loan(IN p_book_id INT, IN p_member_id INT, IN p_quantity INT, IN p_loaned_on DATE) BEGIN DECLARE v_stock INT; IF p_book_id IS NULL OR p_member_id IS NULL OR p_quantity IS NULL OR p_loaned_on IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NULL not allowed'; END IF; IF p_quantity <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Quantity must be positive'; END IF; SELECT copies_available INTO v_stock FROM books WHERE book_id=p_book_id; IF v_stock IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown book'; END IF; IF p_quantity > v_stock THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Not enough copies'; END IF; INSERT INTO loans (book_id, member_id, quantity, loaned_on) VALUES (p_book_id, p_member_id, p_quantity, p_loaned_on); UPDATE books SET copies_available=copies_available-p_quantity WHERE book_id=p_book_id; END //
DELIMITER ;
CALL pr_record_loan(1,1,1,'2026-11-20'); CALL pr_record_loan(1,2,1,'2026-11-20'); CALL pr_record_loan(2,1,2,'2026-11-21'); CALL pr_record_loan(3,2,1,'2026-11-21'); CALL pr_record_loan(2,3,1,'2026-11-22'); CALL pr_record_loan(3,1,2,'2026-11-22');
DELIMITER //
CREATE TRIGGER trg_books_audit AFTER UPDATE ON books FOR EACH ROW BEGIN IF OLD.copies_available <> NEW.copies_available THEN INSERT INTO loan_audit (book_id, old_qty, new_qty, changed_at) VALUES (NEW.book_id, OLD.copies_available, NEW.copies_available, NOW()); END IF; END //
DELIMITER ;
CREATE VIEW v_low_copies AS SELECT title, copies_available FROM books WHERE copies_available < 3;
CREATE INDEX idx_loans_book_date ON loans (book_id, loaned_on);
EXPLAIN SELECT * FROM loans WHERE book_id=1 AND loaned_on BETWEEN '2026-11-20' AND '2026-11-22';
DELIMITER //
CREATE PROCEDURE pr_refresh_loans(IN p_day DATE) BEGIN INSERT INTO daily_loans (loan_date, total_qty, total_loans) SELECT p_day, COALESCE(SUM(quantity),0), COUNT(*) FROM loans WHERE loaned_on=p_day ON DUPLICATE KEY UPDATE total_qty=VALUES(total_qty), total_loans=VALUES(total_loans); END //
DELIMITER ;
CREATE EVENT ev_refresh_loans ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR DO CALL pr_refresh_loans(CURDATE() - INTERVAL 1 DAY);
