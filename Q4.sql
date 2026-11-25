CREATE TABLE rooms (room_id INT PRIMARY KEY AUTO_INCREMENT, room_number VARCHAR(10) NOT NULL UNIQUE, price_per_night DECIMAL(10,2) NOT NULL CHECK (price_per_night > 0), rooms_available INT NOT NULL CHECK (rooms_available >= 0));
CREATE TABLE bookings (booking_id INT PRIMARY KEY AUTO_INCREMENT, room_id INT NOT NULL, guest_name VARCHAR(100) NOT NULL, nights INT NOT NULL CHECK (nights > 0), booked_on DATE NOT NULL, FOREIGN KEY (room_id) REFERENCES rooms(room_id));
CREATE TABLE booking_audit (audit_id INT PRIMARY KEY AUTO_INCREMENT, room_id INT NOT NULL, old_qty INT NOT NULL, new_qty INT NOT NULL, changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP, FOREIGN KEY (room_id) REFERENCES rooms(room_id));
CREATE TABLE daily_bookings (booking_date DATE PRIMARY KEY, total_nights INT NOT NULL DEFAULT 0, total_amount DECIMAL(12,2) NOT NULL DEFAULT 0);
INSERT INTO rooms (room_number, price_per_night, rooms_available) VALUES ('101', 350.00, 5), ('102', 500.00, 3), ('201', 250.00, 8);
DELIMITER //
CREATE FUNCTION fn_booking_value(p_room_id INT, p_nights INT) RETURNS DECIMAL(10,2) DETERMINISTIC BEGIN DECLARE v_price DECIMAL(10,2); IF p_nights IS NULL OR p_nights <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nights must be positive'; END IF; SELECT price_per_night INTO v_price FROM rooms WHERE room_id=p_room_id; IF v_price IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown room'; END IF; RETURN v_price * p_nights; END //
DELIMITER ;
DELIMITER //
CREATE PROCEDURE pr_record_booking(IN p_room_id INT, IN p_guest VARCHAR(100), IN p_nights INT, IN p_booked_on DATE) BEGIN DECLARE v_avail INT; DECLARE v_price DECIMAL(10,2); IF p_room_id IS NULL OR p_guest IS NULL OR p_nights IS NULL OR p_booked_on IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='NULL not allowed'; END IF; IF p_nights <= 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Nights must be positive'; END IF; SELECT rooms_available, price_per_night INTO v_avail, v_price FROM rooms WHERE room_id=p_room_id; IF v_avail IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Unknown room'; END IF; IF p_nights > v_avail THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Not enough rooms'; END IF; INSERT INTO bookings (room_id, guest_name, nights, booked_on) VALUES (p_room_id, p_guest, p_nights, p_booked_on); UPDATE rooms SET rooms_available=rooms_available-1 WHERE room_id=p_room_id; END //
DELIMITER ;
CALL pr_record_booking(1,'Alice Mwale',2,'2026-11-20'); CALL pr_record_booking(1,'John Banda',1,'2026-11-20'); CALL pr_record_booking(2,'Mary Zulu',3,'2026-11-21'); CALL pr_record_booking(3,'Peter Phiri',1,'2026-11-21'); CALL pr_record_booking(3,'Grace Lungu',2,'2026-11-22'); CALL pr_record_booking(2,'David Chanda',1,'2026-11-22');
DELIMITER //
CREATE TRIGGER trg_rooms_audit AFTER UPDATE ON rooms FOR EACH ROW BEGIN IF OLD.rooms_available <> NEW.rooms_available THEN INSERT INTO booking_audit (room_id, old_qty, new_qty, changed_at) VALUES (NEW.room_id, OLD.rooms_available, NEW.rooms_available, NOW()); END IF; END //
DELIMITER ;
CREATE VIEW v_low_rooms AS SELECT room_number, price_per_night, rooms_available FROM rooms WHERE rooms_available < 2;
CREATE INDEX idx_bookings_room_date ON bookings (room_id, booked_on);
EXPLAIN SELECT * FROM bookings WHERE room_id=1 AND booked_on BETWEEN '2026-11-20' AND '2026-11-22';
DELIMITER //
CREATE PROCEDURE pr_refresh_bookings(IN p_day DATE) BEGIN INSERT INTO daily_bookings (booking_date, total_nights, total_amount) SELECT p_day, COALESCE(SUM(nights),0), COALESCE(SUM(nights * 350),0) FROM bookings WHERE booked_on=p_day ON DUPLICATE KEY UPDATE total_nights=VALUES(total_nights), total_amount=VALUES(total_amount); END //
DELIMITER ;
CREATE EVENT ev_refresh_bookings ON SCHEDULE EVERY 1 DAY STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 1 HOUR DO CALL pr_refresh_bookings(CURDATE() - INTERVAL 1 DAY);
