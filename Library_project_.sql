SELECT * FROM books;

SELECT * FROM branch;

SELECT * FROM employees;

SELECT * FROM issued_status;

SELECT * FROM return_status;

SELECT * FROM members;

--PROJECT TASK 

--TASK 1: Create a New Record -- '978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.'
INSERT INTO books(isbn, book_title, category, rental_price, status, author, publisher)
VALUES 
( '978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.');

SELECT * FROM books;

--TASK 2: UPDATE AN EXISTING MEMBER'S ADDRESS
UPDATE members
SET member_address = '125 Main St'
WHERE member_id = 'C101';

SELECT * FROM members;

--TASK 3: Delete a Record from the Issued status table.
--Objective: Delete the record with assued_id = 'IS121' from the issued_status table.
DELETE FROM issued_status 
WHERE issued_id = 'IS121';

SELECT * FROM issued_status;

--TASK 4: Retrieve All Books Issued by a Specific Employee -- Objective: Select all books issued by the employee with emp_id = 'E101'.
SELECT * FROM issued_status 
WHERE issued_emp_id = 'E101';

--Task 5: List Members Who Have Issued More Than One Book -- Objective: Use GROUP BY to find members who have issued more than one book.

SELECT 
	issued_member_id
	--COUNT(issued_id) AS total_book_issued
FROM issued_status
GROUP BY issued_member_id
	HAVING COUNT(issued_id) > 1;
	
--CTAS
--Task 6: Create Summary Tables: Used CTAS to generate new tables based on query results - each book and total book_issued_cnt**
CREATE TABLE book_issued_cnt AS
	SELECT 
		b.isbn,
		b.book_title,
		COUNT(i.issued_id) AS issue_count
	FROM issued_status i
	JOIN  books b
	ON  i.issued_book_isbn =  b.isbn
	GROUP BY b.isbn, b.book_title;

SELECT * FROM book_issued_cnt;

--Task 7. Retrieve All Books in a Specific Category:
SELECT 
	*
 FROM books
 WHERE category = 'Classic';

--Task 8: Find Total Rental Income by Category:
SELECT 
	b.category,
	SUM(rental_price) AS rental_income
FROM books b
JOIN issued_status i
ON  i.issued_book_isbn =  b.isbn
GROUP BY category 
ORDER BY rental_income DESC;

--Task 9: List Members Who Registered in the Last 180 Days:

SELECT * FROM members
WHERE reg_date::DATE >= CURRENT_DATE - INTERVAL '180 days';


INSERT INTO members(member_id, member_name, member_address, reg_date) 
VALUES
('C120', 'John', '122 Main St', '2025-10-01');

--Task 10: List Employees with Their Branch Manager's Name and their branch details:
SELECT 
	e1.*,
	b.manager_id,
	e2.emp_name as manager_name
FROM employees e1
JOIN branch b
ON  b.branch_id = e1.branch_id
JOIN employees e2 
ON b.manager_id = e2.emp_id;

--Task 11. Create a Table of Books with Rental Price Above a Certain Threshold 7USD:
CREATE TABLE expensive_books
AS
SELECT * FROM books
WHERE rental_price > 7.0;

SELECT * FROM expensive_books;

--Task 12: Retrieve the List of Books Not Yet Returned.

SELECT * FROM issued_status ist
LEFT JOIN return_status rs
ON rs.issued_id = ist.issued_id 
WHERE rs.return_id IS NULL;

/*Task 13: Identify Members with Overdue Books
	write a query to identify memers who overdue (assume a 30-day return period).
	Display the members's_id, member's name, book title, issue date, and days overdues.
*/

--issued_status == members == books == return_status
-- filter books which is retun
--overdue > 30

SELECT 
	ist.issued_member_id,
	m.member_name,
	b.book_title,
	ist.issued_date,
	CURRENT_DATE - ist.issued_date as overdues_days
FROM issued_status as ist
JOIN members as m
	ON m.member_id = ist.issued_member_id
JOIN books as b
	ON b.isbn = ist.issued_book_isbn
LEFT JOIN return_status as rs
	ON rs.issued_id = ist.issued_id
WHERE 
	return_date IS NULL 
	AND
	CURRENT_DATE - ist.issued_date > 30
ORDER BY 1;


/* 
	Task 14: Update Books status on Return
	Write a query to update the status of books in the books table to 'Yes' when they are retuned (based on entries in the return_status table).
*/

--METHOD 1: BY MANUALLY
SELECT * FROM issued_status
WHERE issued_book_isbn = '978-0-451-52994-2';

SELECT * FROM books 
WHERE isbn = '978-0-451-52994-2';
	
UPDATE books
SET status = 'No'
WHERE isbn = '978-0-451-52994-2';

SELECT * FROM return_status
WHERE issued_id = 'IS130';

INSERT INTO return_status(return_id, issued_id, return_date, book_quality)
VALUES
('RS125', 'IS130', CURRENT_DATE, 'Good');

UPDATE books
SET status = 'Yes'
WHERE isbn = '978-0-451-52994-2';

SELECT * FROM books 
WHERE isbn = '978-0-451-52994-2';

-- METHOD 2: BY STORE PROCEDURES

CREATE OR REPLACE PROCEDURE add_return_records (
	p_return_id VARCHAR(10),
	p_issued_id  VARCHAR(10),
	p_book_quality VARCHAR(15)
)

LANGUAGE plpgsql
AS $$

DECLARE
	v_isbn VARCHAR(50);
	v_book_name VARCHAR(75);
BEGIN 
	
	  -- Insert return record
	INSERT INTO return_status(
		return_id ,
		issued_id,
		return_date,
		book_quality
	)
	VALUES
	(p_return_id, p_issued_id,CURRENT_DATE, p_book_quality);

	--Get book Details
	SELECT
			issued_book_isbn,
			issued_book_name
			INTO 
			v_isbn,
			v_book_name
	FROM issued_status
	WHERE issued_id = p_issued_id;
	 
    -- Update book status to available
	UPDATE books
	SET status = 'Yes'
	WHERE isbn = v_isbn;
	
    -- Confirmation message
	RAISE NOTICE 'Thank you for returning the book: %', v_book_name;
	
END
$$;

--Testing Function add_return_records

SELECT * FROM books
WHERE isbn = '978-0-307-58837-1';

SELECT * FROM issued_status 
WHERE issued_book_isbn = '978-0-307-58837-1';

SELECT * FROM return_status
WHERE issued_id = 'IS135';

-- calling the function
CALL add_return_records('RS138', 'IS135', 'Good');


/* 
	Task 15: Brach Preferance Report
	Create  a Query that generates a performance report for each branch, showing the number of books issued,
	the number of books returned, and the total revenue generated from book rentals.
*/
CREATE TABLE  branch_performance_report 
AS
SELECT 
	b.branch_id,
	b.manager_id,
	COUNT(ist.issued_id) as total_issued_books,
	COUNT(rs.return_id) as total_returned_books,
	SUM(bk.rental_price) as total_revenue
FROM issued_status as ist
JOIN employees e
	ON e.emp_id = ist.issued_emp_id
JOIN branch as b
	ON e.branch_id = b.branch_id
LEFT JOIN return_status rs 
	ON rs.issued_id = ist.issued_id
JOIN books bk
	ON ist.issued_book_isbn = bk.isbn
GROUP BY b.branch_id, b.manager_id
ORDER BY b.branch_id ASC;

SELECT * FROM branch_performance_report;

/* 
	Task 16: CTAS: Create a table of Active members
	Use the CREATE TABLE AS (CTAS) statement to create a new table, active_user,s containing members.
	who issued at least one book in the last 2 months.
*/
CREATE TABLE active_members 
AS
	SELECT * FROM members 
	WHERE member_id IN(
	
		SELECT  
			DISTINCT issued_member_id
		FROM issued_status 
		WHERE 
			issued_date >= CURRENT_DATE - INTERVAL '2 month'
	);
SELECT * FROM active_members;

/* 
	Task 17: Find employees with the Most Book issues processed
	Write a Query to find the to 3 employees who have processed the most book issues.
	Display the employee name, number of books processed, and their branch.
*/

SELECT 
	e.emp_name,
	b.*,
	COUNT(ist.issued_id) AS no_books_processed
	
FROM issued_status as ist
JOIN employees e 
	ON e.emp_id = ist.issued_emp_id
JOIN branch as b
	ON b.branch_id = e.branch_id
GROUP BY 1, 2;

/*
	Task 18: Solve by yourself..
*/



/*
	Task 19: Stored Precedure Objectives:
	Create a Stored Procedure to manage the status of books in a library system.

*/


CREATE OR REPLACE PROCEDURE issue_book(
    p_issued_id VARCHAR(10),
    p_issued_member_id VARCHAR(10),
    p_issued_book_isbn VARCHAR(25),
    p_issued_emp_id VARCHAR(10)
)
LANGUAGE plpgsql
AS $$

DECLARE
    v_status VARCHAR(15);

BEGIN 

    -- Get book status
    SELECT status
    INTO v_status
    FROM books
    WHERE isbn = p_issued_book_isbn;

    -- Check if book exists
    IF v_status IS NULL THEN
        RAISE NOTICE 'Book not found with ISBN: %', p_issued_book_isbn;
        RETURN;
    END IF;

    -- Correct condition
    IF LOWER(v_status) = 'yes' THEN 

        -- Insert record
        INSERT INTO issued_status(
            issued_id, 
            issued_member_id,
            issued_date, 
            issued_book_isbn, 
            issued_emp_id
        )
        VALUES (
            p_issued_id, 
            p_issued_member_id,
            CURRENT_DATE, 
            p_issued_book_isbn, 
            p_issued_emp_id
        );

        -- Update book status to NOT available
        UPDATE books
        SET status = 'no'
        WHERE isbn = p_issued_book_isbn;

        RAISE NOTICE 'Book issued successfully. ISBN: %', p_issued_book_isbn;

    ELSE 
        RAISE NOTICE Book is currently unavailable. ISBN: %', p_issued_book_isbn;
    END IF;

END;
$$;


CALL issue_book('IS155', 'C108','978-0-330-25864-8' ,'E104');


SELECT * FROM issued_status;
	