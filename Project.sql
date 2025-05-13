'''
This code includes 
  Creating credentials for DBMS, 
  Import ONNX model from AI23_Bucket,
  Insert data into supply chain tables,
  Implement vector embedding by using all_MiniLM_L12_v2.onnx,
  Perform a semantic search based on vector, 
  Perform a hybrid search based on vector 70 percent and key-value 30 percent.
  
'''

SELECT * FROM USER_CREDENTIALS;
SELECT * FROM DBMS_CLOUD.LIST_OBJECTS('FREE23AI_CRED', '$BUCKET_ID');

GRANT execute on dbms_cloud To FREE23AI_CRED;
GRANT create mining model TO FREE23AI_CRED;

BEGIN
DBMS_CLOUD.CREATE_CREDENTIAL(
  credential_name => 'FREE23AI_CRED',
  username => 'My_OCI_Username',
  password => 'My_OCI_Username_AuthToken'
);
END;

DECLARE
    ONNX_MOD_FILE VARCHAR2(100) := 'all_MiniLM_L12_v2.onnx';
    MODNAME VARCHAR2(500);
    LOCATION_URI VARCHAR2(200) := '$BUCKET_SECRET';
    META_DATA CLOB;
BEGIN
    -- Define a simpler model name to avoid potential issues
    MODNAME := 'MINILM_MODEL'; -- Shorter, simpler name

    -- Load the ONNX model using the correct function call
    DBMS_VECTOR.LOAD_ONNX_MODEL(
        model_name => MODNAME,
        model_data => dbms_cloud.get_object(
            credential_name => 'FREE23AI_CRED',
            object_uri      => LOCATION_URI
        ),
        metadata => JSON('{
            "function" : "embedding",
            "embeddingOutput" : "embedding",
            "input": {"input": ["DATA"]}
        }')
    );

    DBMS_OUTPUT.PUT_LINE('New model successfully loaded with name: ' || MODNAME);
END;

SELECT * FROM user_mining_models WHERE model_name = 'MINILM_MODEL';

SELECT MODEL_NAME, MINING_FUNCTION, ALGORITHM,
ALGORITHM_TYPE, MODEL_SIZE
FROM user_mining_models
WHERE model_name = 'MINILM_MODEL'
ORDER BY MODEL_NAME;


SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'The quick brown fox jumped' AS DATA)) AS embedding
FROM dual;

SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'The quick brown fox jumped over a white dog' AS DATA)) AS embedding
FROM dual;

-- SELECT TO_VECTOR(VECTOR_EMBEDDING(doc_model USING 'hello' as data)) AS embedding;

SELECT * FROM CUSTOMER_QUESTIONS;

DECLARE
    v_embedding VECTOR; -- Using VECTOR type instead of BLOB
BEGIN
    -- Generate the embedding for the input question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Can you suggest me some action cum thriller movies?' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Insert the question and generated embedding into the table
    INSERT INTO CUSTOMER_QUESTIONS (customer_id, cust_question, embedding)
    VALUES (2, 'Can you suggest me some action cum thriller movies?', v_embedding);

    COMMIT; -- Commit the transaction to persist the data
    DBMS_OUTPUT.PUT_LINE('Successfully inserted the question and embedding into the table.');
END;

SELECT * FROM CUSTOMER_QUESTIONS;

SELECT * FROM ITEMS;

INSERT INTO ITEMS (ITEM_ID, ITEM_NAME, ITEM_TYPE, UNIT_PRICE, QUANTITY_IN_STOCK, SUPPLIER_ID)
VALUES (1001, 'Military Vehicle', 'Vehicles', 150000, 50, 101);

INSERT INTO ITEMS (ITEM_ID, ITEM_NAME, ITEM_TYPE, UNIT_PRICE, QUANTITY_IN_STOCK, SUPPLIER_ID)
VALUES (1002, 'Assault Rifle', 'Weapons', 1200, 200, 102);

INSERT INTO ITEMS (ITEM_ID, ITEM_NAME, ITEM_TYPE, UNIT_PRICE, QUANTITY_IN_STOCK, SUPPLIER_ID)
VALUES (1003, 'Medical Equipment Kit', 'Medical', 3000, 100, 103);

INSERT INTO ITEMS (ITEM_ID, ITEM_NAME, ITEM_TYPE, UNIT_PRICE, QUANTITY_IN_STOCK, SUPPLIER_ID)
VALUES (1004, 'Communications Radio', 'Electronics', 7500, 75, 101);

INSERT INTO ITEMS (ITEM_ID, ITEM_NAME, ITEM_TYPE, UNIT_PRICE, QUANTITY_IN_STOCK, SUPPLIER_ID)
VALUES (1005, 'Ammunition (5.56mm)', 'Ammunition', 0.5, 50000, 102);

SELECT * FROM MAINTENANCE_LOGS;

DECLARE
    v_embedding VECTOR; -- Using VECTOR type for the embedding
BEGIN
    -- Insert the data and generate embeddings for each record
    INSERT INTO MAINTENANCE_LOGS (LOG_ID, ITEM_ID, MAINTENANCE_DATE, LOG_TEXT, TECHNICIAN_ID, NEXT_SERVICE_DATE)
    VALUES (1, 1001, TO_DATE('2023-04-01', 'YYYY-MM-DD'), 'Routine maintenance. Oil leakage noticed. Replaced gasket.', 6001, TO_DATE('2023-07-01', 'YYYY-MM-DD'));

    -- Generate the embedding for the LOG_TEXT of the first log
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Routine maintenance. Oil leakage noticed. Replaced gasket.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the LOG_TEXT_VECTOR column with the generated embedding
    UPDATE MAINTENANCE_LOGS
    SET LOG_TEXT_VECTOR = v_embedding
    WHERE LOG_ID = 1;

    -- Repeat the process for the other records
    INSERT INTO MAINTENANCE_LOGS (LOG_ID, ITEM_ID, MAINTENANCE_DATE, LOG_TEXT, TECHNICIAN_ID, NEXT_SERVICE_DATE)
    VALUES (2, 1002, TO_DATE('2023-04-15', 'YYYY-MM-DD'), 'Weapon malfunction during training. Firing mechanism repaired.', 6002, TO_DATE('2023-10-15', 'YYYY-MM-DD'));

    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Weapon malfunction during training. Firing mechanism repaired.' AS DATA))
    INTO v_embedding
    FROM dual;

    UPDATE MAINTENANCE_LOGS
    SET LOG_TEXT_VECTOR = v_embedding
    WHERE LOG_ID = 2;

    INSERT INTO MAINTENANCE_LOGS (LOG_ID, ITEM_ID, MAINTENANCE_DATE, LOG_TEXT, TECHNICIAN_ID, NEXT_SERVICE_DATE)
    VALUES (3, 1003, TO_DATE('2023-05-10', 'YYYY-MM-DD'), 'Engine failure. Overheating issues. Coolant system replaced.', 6003, TO_DATE('2023-06-10', 'YYYY-MM-DD'));

    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Engine failure. Overheating issues. Coolant system replaced.' AS DATA))
    INTO v_embedding
    FROM dual;

    UPDATE MAINTENANCE_LOGS
    SET LOG_TEXT_VECTOR = v_embedding
    WHERE LOG_ID = 3;

    INSERT INTO MAINTENANCE_LOGS (LOG_ID, ITEM_ID, MAINTENANCE_DATE, LOG_TEXT, TECHNICIAN_ID, NEXT_SERVICE_DATE)
    VALUES (4, 1004, TO_DATE('2023-05-20', 'YYYY-MM-DD'), 'Preventive maintenance. Software update completed.', 6004, TO_DATE('2023-12-20', 'YYYY-MM-DD'));

    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Preventive maintenance. Software update completed.' AS DATA))
    INTO v_embedding
    FROM dual;

    UPDATE MAINTENANCE_LOGS
    SET LOG_TEXT_VECTOR = v_embedding
    WHERE LOG_ID = 4;

    COMMIT; -- Commit the transaction to persist the data
    DBMS_OUTPUT.PUT_LINE('Successfully inserted the data and embeddings into the MAINTENANCE_LOGS table.');
END;

SELECT * FROM ORDERS;

INSERT INTO ORDERS (ORDER_ID, ORDER_DATE, EXPECTED_DELIVERY, ACTUAL_DELIVERY, SUPPLIER_ID, STATUS)
VALUES (2001, TO_DATE('2023-01-10', 'YYYY-MM-DD'), TO_DATE('2023-03-01', 'YYYY-MM-DD'), TO_DATE('2023-02-28', 'YYYY-MM-DD'), 101, 'Delivered');

INSERT INTO ORDERS (ORDER_ID, ORDER_DATE, EXPECTED_DELIVERY, ACTUAL_DELIVERY, SUPPLIER_ID, STATUS)
VALUES (2002, TO_DATE('2023-02-15', 'YYYY-MM-DD'), TO_DATE('2023-03-10', 'YYYY-MM-DD'), TO_DATE('2023-03-12', 'YYYY-MM-DD'), 102, 'Delivered');

INSERT INTO ORDERS (ORDER_ID, ORDER_DATE, EXPECTED_DELIVERY, ACTUAL_DELIVERY, SUPPLIER_ID, STATUS)
VALUES (2003, TO_DATE('2023-03-05', 'YYYY-MM-DD'), TO_DATE('2023-05-01', 'YYYY-MM-DD'), NULL, 103, 'Pending'); 

INSERT INTO ORDERS (ORDER_ID, ORDER_DATE, EXPECTED_DELIVERY, ACTUAL_DELIVERY, SUPPLIER_ID, STATUS)
VALUES (2004, TO_DATE('2023-03-20', 'YYYY-MM-DD'), TO_DATE('2023-04-15', 'YYYY-MM-DD'), TO_DATE('2023-04-20', 'YYYY-MM-DD'), 101, 'Delivered');

SELECT * FROM ORDER_ITEMS;

INSERT INTO ORDER_ITEMS (ORDER_ITEM_ID, ORDER_ID, ITEM_ID, QUANTITY_ORDERED, PRICE_PER_UNIT)
VALUES (3001, 2001, 1001, 10, 150000);

INSERT INTO ORDER_ITEMS (ORDER_ITEM_ID, ORDER_ID, ITEM_ID, QUANTITY_ORDERED, PRICE_PER_UNIT)
VALUES (3002, 2002, 1002, 500, 1200);

INSERT INTO ORDER_ITEMS (ORDER_ITEM_ID, ORDER_ID, ITEM_ID, QUANTITY_ORDERED, PRICE_PER_UNIT)
VALUES (3003, 2003, 1003, 50, 3000);

INSERT INTO ORDER_ITEMS (ORDER_ITEM_ID, ORDER_ID, ITEM_ID, QUANTITY_ORDERED, PRICE_PER_UNIT)
VALUES (3004, 2004, 1004, 20, 7500);

INSERT INTO ORDER_ITEMS (ORDER_ITEM_ID, ORDER_ID, ITEM_ID, QUANTITY_ORDERED, PRICE_PER_UNIT)
VALUES (3005, 2004, 1005, 10000, 0.5);

SELECT * FROM PERSONNEL; 

INSERT INTO PERSONNEL (PERSONNEL_ID, FIRST_NAME, LAST_NAME, RANK, ROLE, ASSIGNED_WAREHOUSE)
VALUES (6001, 'Mark', 'Davis', 'Captain', 'Warehouse Manager', 4001);

INSERT INTO PERSONNEL (PERSONNEL_ID, FIRST_NAME, LAST_NAME, RANK, ROLE, ASSIGNED_WAREHOUSE)
VALUES (6002, 'Sarah', 'Lee', 'Major', 'Logistics Officer', 4002);

INSERT INTO PERSONNEL (PERSONNEL_ID, FIRST_NAME, LAST_NAME, RANK, ROLE, ASSIGNED_WAREHOUSE)
VALUES (6003, 'James', 'Carter', 'Lieutenant', 'Supply Chain Supervisor', 4003);

INSERT INTO PERSONNEL (PERSONNEL_ID, FIRST_NAME, LAST_NAME, RANK, ROLE, ASSIGNED_WAREHOUSE)
VALUES (6004, 'Emily', 'Turner', 'Sergeant', 'Inventory Control Officer', 4001);

INSERT INTO PERSONNEL (PERSONNEL_ID, FIRST_NAME, LAST_NAME, RANK, ROLE, ASSIGNED_WAREHOUSE)
VALUES (6005, 'Lucas', 'Moore', 'Corporal', 'Shipment Coordinator', 4002);

SELECT * FROM PROCUREMENT_DOCUMENTS;

DECLARE
    v_embedding VECTOR; -- Using VECTOR type for the embedding
BEGIN
    -- Insert the first document and generate the embedding for DOCUMENT_TEXT
    INSERT INTO PROCUREMENT_DOCUMENTS (DOCUMENT_ID, DOCUMENT_NAME, DOCUMENT_TEXT, SUPPLIER_ID, DATE_UPLOADED)
    VALUES (1, 'Supplier X Contract', 'This contract, effective from January 1, 2023, outlines the procurement of 100 units of heavy-duty military vehicles. Payment terms: 30% upfront, 40% on delivery, and 30% after inspection. Late delivery incurs a penalty of 2% per week overdue.', 101, TO_DATE('2023-01-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));

    -- Generate the embedding for the DOCUMENT_TEXT of the first document
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'This contract, effective from January 1, 2023, outlines the procurement of 100 units of heavy-duty military vehicles. Payment terms: 30% upfront, 40% on delivery, and 30% after inspection. Late delivery incurs a penalty of 2% per week overdue.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the DOCUMENT_TEXT_VECTOR column with the generated embedding
    UPDATE PROCUREMENT_DOCUMENTS
    SET DOCUMENT_TEXT_VECTOR = v_embedding
    WHERE DOCUMENT_ID = 1;

    -- Insert the second document and generate the embedding for DOCUMENT_TEXT
    INSERT INTO PROCUREMENT_DOCUMENTS (DOCUMENT_ID, DOCUMENT_NAME, DOCUMENT_TEXT, SUPPLIER_ID, DATE_UPLOADED)
    VALUES (2, 'Supplier Y Agreement', 'Agreement with Supplier Y for providing 50,000 rounds of ammunition. Delivery must occur by March 2023. Payment terms: Net 60 days. Any delivery delays will result in a 5% deduction from total payment for each week of delay.', 102, TO_DATE('2023-02-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));

    -- Generate the embedding for the DOCUMENT_TEXT of the second document
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Agreement with Supplier Y for providing 50,000 rounds of ammunition. Delivery must occur by March 2023. Payment terms: Net 60 days. Any delivery delays will result in a 5% deduction from total payment for each week of delay.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the DOCUMENT_TEXT_VECTOR column with the generated embedding
    UPDATE PROCUREMENT_DOCUMENTS
    SET DOCUMENT_TEXT_VECTOR = v_embedding
    WHERE DOCUMENT_ID = 2;

    -- Insert the third document and generate the embedding for DOCUMENT_TEXT
    INSERT INTO PROCUREMENT_DOCUMENTS (DOCUMENT_ID, DOCUMENT_NAME, DOCUMENT_TEXT, SUPPLIER_ID, DATE_UPLOADED)
    VALUES (3, 'Supplier Z Contract', 'Supplier Z will provide specialized medical equipment for field hospitals. Total value of $1.5 million. Payment is scheduled in two installments: 50% on delivery and 50% 60 days after delivery. Inspection of the equipment is mandatory.', 103, TO_DATE('2023-03-15 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));

    -- Generate the embedding for the DOCUMENT_TEXT of the third document
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Supplier Z will provide specialized medical equipment for field hospitals. Total value of $1.5 million. Payment is scheduled in two installments: 50% on delivery and 50% 60 days after delivery. Inspection of the equipment is mandatory.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the DOCUMENT_TEXT_VECTOR column with the generated embedding
    UPDATE PROCUREMENT_DOCUMENTS
    SET DOCUMENT_TEXT_VECTOR = v_embedding
    WHERE DOCUMENT_ID = 3;

    COMMIT; -- Commit the transaction to persist the data
    DBMS_OUTPUT.PUT_LINE('Successfully inserted the procurement documents and embeddings into the table.');
END;


SELECT * FROM SHIPMENTS;

INSERT INTO SHIPMENTS (SHIPMENT_ID, SHIPMENT_DATE, WAREHOUSE_ID, DESTINATION, SHIPMENT_STATUS)
VALUES (7001, TO_DATE('2023-04-01', 'YYYY-MM-DD'), 4001, 'Forward Base X', 'Delivered');

INSERT INTO SHIPMENTS (SHIPMENT_ID, SHIPMENT_DATE, WAREHOUSE_ID, DESTINATION, SHIPMENT_STATUS)
VALUES (7002, TO_DATE('2023-04-10', 'YYYY-MM-DD'), 4002, 'Base Y', 'En Route');

INSERT INTO SHIPMENTS (SHIPMENT_ID, SHIPMENT_DATE, WAREHOUSE_ID, DESTINATION, SHIPMENT_STATUS)
VALUES (7003, TO_DATE('2023-04-15', 'YYYY-MM-DD'), 4003, 'Forward Base Z', 'Pending');

INSERT INTO SHIPMENTS (SHIPMENT_ID, SHIPMENT_DATE, WAREHOUSE_ID, DESTINATION, SHIPMENT_STATUS)
VALUES (7004, TO_DATE('2023-05-01', 'YYYY-MM-DD'), 4001, 'Base A', 'Delivered');

SELECT * FROM SHIPMENT_ITEMS;

INSERT INTO SHIPMENT_ITEMS (SHIPMENT_ITEM_ID, SHIPMENT_ID, ITEM_ID, QUANTITY_SHIPPED)
VALUES (8001, 7001, 1001, 5);

INSERT INTO SHIPMENT_ITEMS (SHIPMENT_ITEM_ID, SHIPMENT_ID, ITEM_ID, QUANTITY_SHIPPED)
VALUES (8002, 7001, 1002, 50);

INSERT INTO SHIPMENT_ITEMS (SHIPMENT_ITEM_ID, SHIPMENT_ID, ITEM_ID, QUANTITY_SHIPPED)
VALUES (8003, 7002, 1003, 10);

INSERT INTO SHIPMENT_ITEMS (SHIPMENT_ITEM_ID, SHIPMENT_ID, ITEM_ID, QUANTITY_SHIPPED)
VALUES (8004, 7003, 1004, 8);

INSERT INTO SHIPMENT_ITEMS (SHIPMENT_ITEM_ID, SHIPMENT_ID, ITEM_ID, QUANTITY_SHIPPED)
VALUES (8005, 7004, 1005, 5000);

SELECT * FROM SHIPMENT_REPORTS;

DECLARE
    v_embedding VECTOR; -- Using VECTOR type for the embedding
BEGIN
    -- Insert the first report and generate the embedding for REPORT_TEXT
    INSERT INTO SHIPMENT_REPORTS (REPORT_ID, SHIPMENT_ID, REPORT_TEXT, REPORT_DATE, SUBMITTED_BY)
    VALUES (1, 7001, 'Shipment 2001 encountered a delay due to severe weather. Expected delivery was pushed back by 3 days. No damage reported, but the route had to be altered for safety reasons.', TO_DATE('2023-03-28 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Sgt. Mark Davis');

    -- Generate the embedding for the REPORT_TEXT of the first report
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Shipment 2001 encountered a delay due to severe weather. Expected delivery was pushed back by 3 days. No damage reported, but the route had to be altered for safety reasons.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the REPORT_TEXT_VECTOR column with the generated embedding
    UPDATE SHIPMENT_REPORTS
    SET REPORT_TEXT_VECTOR = v_embedding
    WHERE REPORT_ID = 1;

    -- Insert the second report and generate the embedding for REPORT_TEXT
    INSERT INTO SHIPMENT_REPORTS (REPORT_ID, SHIPMENT_ID, REPORT_TEXT, REPORT_DATE, SUBMITTED_BY)
    VALUES (2, 7002, 'Shipment 2002 arrived on time, but two crates were found damaged. Items inside appear intact, but further inspection is recommended before use.', TO_DATE('2023-04-02 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Cpl. Maria Gomez');

    -- Generate the embedding for the REPORT_TEXT of the second report
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Shipment 2002 arrived on time, but two crates were found damaged. Items inside appear intact, but further inspection is recommended before use.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the REPORT_TEXT_VECTOR column with the generated embedding
    UPDATE SHIPMENT_REPORTS
    SET REPORT_TEXT_VECTOR = v_embedding
    WHERE REPORT_ID = 2;

    -- Insert the third report and generate the embedding for REPORT_TEXT
    INSERT INTO SHIPMENT_REPORTS (REPORT_ID, SHIPMENT_ID, REPORT_TEXT, REPORT_DATE, SUBMITTED_BY)
    VALUES (3, 7003, 'Unexpected checkpoint delays caused a minor hold-up in shipment 2003. However, all items arrived without further issues. Recommend alternative routes for future shipments.', TO_DATE('2023-04-10 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Sgt. Alex Thompson');

    -- Generate the embedding for the REPORT_TEXT of the third report
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Unexpected checkpoint delays caused a minor hold-up in shipment 2003. However, all items arrived without further issues. Recommend alternative routes for future shipments.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the REPORT_TEXT_VECTOR column with the generated embedding
    UPDATE SHIPMENT_REPORTS
    SET REPORT_TEXT_VECTOR = v_embedding
    WHERE REPORT_ID = 3;

    -- Insert the fourth report and generate the embedding for REPORT_TEXT
    INSERT INTO SHIPMENT_REPORTS (REPORT_ID, SHIPMENT_ID, REPORT_TEXT, REPORT_DATE, SUBMITTED_BY)
    VALUES (4, 7004, 'Shipment 2004 was flagged for an inspection at customs, causing a significant delay. Equipment passed inspection, but delivery was delayed by 5 days.', TO_DATE('2023-04-18 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Lt. David Harper');

    -- Generate the embedding for the REPORT_TEXT of the fourth report
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Shipment 2004 was flagged for an inspection at customs, causing a significant delay. Equipment passed inspection, but delivery was delayed by 5 days.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the REPORT_TEXT_VECTOR column with the generated embedding
    UPDATE SHIPMENT_REPORTS
    SET REPORT_TEXT_VECTOR = v_embedding
    WHERE REPORT_ID = 4;

    COMMIT; -- Commit the transaction to persist the data
    DBMS_OUTPUT.PUT_LINE('Successfully inserted the shipment reports and embeddings into the table.');
END;

SELECT * FROM STOCK_LEVELS;

INSERT INTO STOCK_LEVELS (QUANTITY_IN_STOCK, ITEM_ID, WAREHOUSE_ID, STOCK_LEVEL_ID)
VALUES (10, 1001, 4001, 5001);

INSERT INTO STOCK_LEVELS (QUANTITY_IN_STOCK, ITEM_ID, WAREHOUSE_ID, STOCK_LEVEL_ID)
VALUES (100, 1002, 4001, 5002);

INSERT INTO STOCK_LEVELS (QUANTITY_IN_STOCK, ITEM_ID, WAREHOUSE_ID, STOCK_LEVEL_ID)
VALUES (20, 1003, 4002, 5003);

INSERT INTO STOCK_LEVELS (QUANTITY_IN_STOCK, ITEM_ID, WAREHOUSE_ID, STOCK_LEVEL_ID)
VALUES (15, 1004, 4002, 5004);

INSERT INTO STOCK_LEVELS (QUANTITY_IN_STOCK, ITEM_ID, WAREHOUSE_ID, STOCK_LEVEL_ID)
VALUES (10000, 1005, 4003, 5005);

SELECT * FROM SUPPLIERS;

INSERT INTO SUPPLIERS (SUPPLIER_ID, SUPPLIER_NAME, CONTACT_NAME, CONTACT_PHONE, CONTACT_EMAIL, ADDRESS, CONTRACT_START_DATE, CONTRACT_END_DATE)
VALUES (101, 'Supplier X', 'John Doe', '555-1234', 'john.doe@supplierx.com', '123 Military Rd, City A', TO_DATE('2023-01-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_DATE('2025-01-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));

INSERT INTO SUPPLIERS (SUPPLIER_ID, SUPPLIER_NAME, CONTACT_NAME, CONTACT_PHONE, CONTACT_EMAIL, ADDRESS, CONTRACT_START_DATE, CONTRACT_END_DATE)
VALUES (102, 'Supplier Y', 'Sarah Johnson', '555-5678', 'sarah.j@suppliery.com', '789 Supply St, City B', TO_DATE('2023-02-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_DATE('2024-12-31 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));

INSERT INTO SUPPLIERS (SUPPLIER_ID, SUPPLIER_NAME, CONTACT_NAME, CONTACT_PHONE, CONTACT_EMAIL, ADDRESS, CONTRACT_START_DATE, CONTRACT_END_DATE)
VALUES (103, 'Supplier Z', 'James Smith', '555-8765', 'james.s@supplierz.com', '456 Defense Blvd, City C', TO_DATE('2023-03-15 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), TO_DATE('2025-06-30 12:00:00', 'YYYY-MM-DD HH24:MI:SS'));

SELECT * FROM SUPPLIER_REVIEWS; 

DECLARE
    v_embedding VECTOR; -- Using VECTOR type for the embedding
BEGIN
    -- Insert the first review and generate the embedding for REVIEW_TEXT
    INSERT INTO SUPPLIER_REVIEWS (REVIEW_ID, SUPPLIER_ID, REVIEW_TEXT, RATING, REVIEW_DATE, SUBMITTED_BY)
    VALUES (1, 101, 'Supplier X consistently delivers on time, but the quality of the vehicles has been questionable. We had multiple breakdowns within the first six months of use.', 3.5, TO_DATE('2023-03-20 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Sgt. John Doe');

    -- Generate the embedding for the REVIEW_TEXT of the first review
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Supplier X consistently delivers on time, but the quality of the vehicles has been questionable. We had multiple breakdowns within the first six months of use.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the SUPPLY_REVIEW_VECTOR column with the generated embedding
    UPDATE SUPPLIER_REVIEWS
    SET SUPPLY_REVIEW_VECTOR = v_embedding
    WHERE REVIEW_ID = 1;

    -- Insert the second review and generate the embedding for REVIEW_TEXT
    INSERT INTO SUPPLIER_REVIEWS (REVIEW_ID, SUPPLIER_ID, REVIEW_TEXT, RATING, REVIEW_DATE, SUBMITTED_BY)
    VALUES (2, 102, 'Supplier Y provided ammunition as contracted, but the shipment was delayed by two weeks, and they were difficult to reach for updates. Communication needs improvement.', 2, TO_DATE('2023-04-05 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Lt. Sarah Anderson');

    -- Generate the embedding for the REVIEW_TEXT of the second review
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Supplier Y provided ammunition as contracted, but the shipment was delayed by two weeks, and they were difficult to reach for updates. Communication needs improvement.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the SUPPLY_REVIEW_VECTOR column with the generated embedding
    UPDATE SUPPLIER_REVIEWS
    SET SUPPLY_REVIEW_VECTOR = v_embedding
    WHERE REVIEW_ID = 2;

    -- Insert the third review and generate the embedding for REVIEW_TEXT
    INSERT INTO SUPPLIER_REVIEWS (REVIEW_ID, SUPPLIER_ID, REVIEW_TEXT, RATING, REVIEW_DATE, SUBMITTED_BY)
    VALUES (3, 103, 'Great experience with Supplier Z. They were on time, responsive to questions, and provided high-quality medical equipment for our field hospital.', 5, TO_DATE('2023-04-15 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Cap. James Carter');

    -- Generate the embedding for the REVIEW_TEXT of the third review
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Great experience with Supplier Z. They were on time, responsive to questions, and provided high-quality medical equipment for our field hospital.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the SUPPLY_REVIEW_VECTOR column with the generated embedding
    UPDATE SUPPLIER_REVIEWS
    SET SUPPLY_REVIEW_VECTOR = v_embedding
    WHERE REVIEW_ID = 3;

    -- Insert the fourth review and generate the embedding for REVIEW_TEXT
    INSERT INTO SUPPLIER_REVIEWS (REVIEW_ID, SUPPLIER_ID, REVIEW_TEXT, RATING, REVIEW_DATE, SUBMITTED_BY)
    VALUES (4, 101, 'We’ve experienced mechanical failures in two-thirds of the vehicles we procured from Supplier X. This issue needs to be addressed in future contracts.', 2, TO_DATE('2023-05-01 12:00:00', 'YYYY-MM-DD HH24:MI:SS'), 'Maj. Emma Williams');

    -- Generate the embedding for the REVIEW_TEXT of the fourth review
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'We’ve experienced mechanical failures in two-thirds of the vehicles we procured from Supplier X. This issue needs to be addressed in future contracts.' AS DATA))
    INTO v_embedding
    FROM dual;

    -- Update the SUPPLY_REVIEW_VECTOR column with the generated embedding
    UPDATE SUPPLIER_REVIEWS
    SET SUPPLY_REVIEW_VECTOR = v_embedding
    WHERE REVIEW_ID = 4;

    COMMIT; -- Commit the transaction to persist the data
    DBMS_OUTPUT.PUT_LINE('Successfully inserted the supplier reviews and embeddings into the table.');
END;


SELECT * FROM WAREHOUSE;

INSERT INTO WAREHOUSE (WAREHOUSE_ID, LOCATION, CAPACITY, MANAGER_NAME)
VALUES (4001, 'Base A', 5000, 'Captain Mark Davis');

INSERT INTO WAREHOUSE (WAREHOUSE_ID, LOCATION, CAPACITY, MANAGER_NAME)
VALUES (4002, 'Base B', 7000, 'Major Sarah Lee');

INSERT INTO WAREHOUSE (WAREHOUSE_ID, LOCATION, CAPACITY, MANAGER_NAME)
VALUES (4003, 'Base C', 8000, 'Lt. James Carter');


CREATE TABLE USER_QUESTIONS (
    QUESTION_ID NUMBER PRIMARY KEY,
    QUESTION_TEXT VARCHAR2(500),
    QUESTION_VECTOR VECTOR
);

SELECT * FROM USER_QUESTIONS;

DECLARE
    v_question_vector VECTOR; -- To store the question vector embedding
BEGIN
    -- Insert first question
    INSERT INTO USER_QUESTIONS (QUESTION_ID, QUESTION_TEXT, QUESTION_VECTOR)
    VALUES (1, 'What is the status of shipment 2001?', NULL);
    
    -- Generate vector embedding for the first question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'What is the status of shipment 2001?' AS DATA))
    INTO v_question_vector
    FROM dual;
    
    -- Update the question vector
    UPDATE USER_QUESTIONS
    SET QUESTION_VECTOR = v_question_vector
    WHERE QUESTION_ID = 1;

    -- Insert second question
    INSERT INTO USER_QUESTIONS (QUESTION_ID, QUESTION_TEXT, QUESTION_VECTOR)
    VALUES (2, 'Has Supplier X provided good quality vehicles?', NULL);
    
    -- Generate vector embedding for the second question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Has Supplier X provided good quality vehicles?' AS DATA))
    INTO v_question_vector
    FROM dual;

    -- Update the question vector
    UPDATE USER_QUESTIONS
    SET QUESTION_VECTOR = v_question_vector
    WHERE QUESTION_ID = 2;

    -- Insert third question
    INSERT INTO USER_QUESTIONS (QUESTION_ID, QUESTION_TEXT, QUESTION_VECTOR)
    VALUES (3, 'What items were shipped with shipment 2002?', NULL);
    
    -- Generate vector embedding for the third question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'What items were shipped with shipment 2002?' AS DATA))
    INTO v_question_vector
    FROM dual;

    -- Update the question vector
    UPDATE USER_QUESTIONS
    SET QUESTION_VECTOR = v_question_vector
    WHERE QUESTION_ID = 3;

    -- Insert fourth question
    INSERT INTO USER_QUESTIONS (QUESTION_ID, QUESTION_TEXT, QUESTION_VECTOR)
    VALUES (4, 'What is the delivery status of Supplier Y?', NULL);
    
    -- Generate vector embedding for the fourth question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'What is the delivery status of Supplier Y?' AS DATA))
    INTO v_question_vector
    FROM dual;

    -- Update the question vector
    UPDATE USER_QUESTIONS
    SET QUESTION_VECTOR = v_question_vector
    WHERE QUESTION_ID = 4;

    -- Insert fifth question
    INSERT INTO USER_QUESTIONS (QUESTION_ID, QUESTION_TEXT, QUESTION_VECTOR)
    VALUES (5, 'What was the delay reason for shipment 2003?', NULL);
    
    -- Generate vector embedding for the fifth question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'What was the delay reason for shipment 2003?' AS DATA))
    INTO v_question_vector
    FROM dual;

    -- Update the question vector
    UPDATE USER_QUESTIONS
    SET QUESTION_VECTOR = v_question_vector
    WHERE QUESTION_ID = 5;

    COMMIT; -- Commit the transaction to persist the data
    DBMS_OUTPUT.PUT_LINE('Successfully inserted user questions and their embeddings.');
END;

DECLARE
    v_question_vector VECTOR; -- To store the question vector embedding
BEGIN
    -- Insert first question
    INSERT INTO USER_QUESTIONS (QUESTION_ID, QUESTION_TEXT, QUESTION_VECTOR)
    VALUES (6, 'Which vendor is best when it comes to less delay and high quality?', NULL);
    
    -- Generate vector embedding for the first question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Which vendor is best when it comes to less delay and high quality?' AS DATA))
    INTO v_question_vector
    FROM dual;
    
    -- Update the question vector
    UPDATE USER_QUESTIONS
    SET QUESTION_VECTOR = v_question_vector
    WHERE QUESTION_ID = 6;

    COMMIT;
END;

DECLARE
    v_question_vector VECTOR; -- To store the question vector embedding
BEGIN
    -- Insert first question
    INSERT INTO USER_QUESTIONS (QUESTION_ID, QUESTION_TEXT, QUESTION_VECTOR)
    VALUES (7, 'Which supplier has the least delay and the best quality products?', NULL);
    
    -- Generate vector embedding for the first question
    SELECT TO_VECTOR(VECTOR_EMBEDDING(MINILM_MODEL USING 'Which supplier has the least delay and the best quality products?' AS DATA))
    INTO v_question_vector
    FROM dual;
    
    -- Update the question vector
    UPDATE USER_QUESTIONS
    SET QUESTION_VECTOR = v_question_vector
    WHERE QUESTION_ID = 7;

    COMMIT;
END;

SELECT * FROM USER_QUESTIONS;

SELECT sr.report_id, sr.shipment_id, sr.report_text, sr.report_date, sr.submitted_by
FROM shipment_reports sr
CROSS JOIN (
    SELECT question_vector AS vector
    FROM user_questions
    WHERE question_id = 7
) uq
ORDER BY VECTOR_DISTANCE(sr.report_text_vector, uq.vector, EUCLIDEAN)
FETCH FIRST 1 ROWS ONLY;


SELECT sr.review_id, sr.supplier_id, sr.review_text, sr.rating, sr.review_date, sr.submitted_by
FROM supplier_reviews sr
CROSS JOIN (
    SELECT question_vector AS vector
    FROM user_questions
    WHERE question_id = 7
) uq
ORDER BY VECTOR_DISTANCE(sr.supply_review_vector, uq.vector, MANHATTAN)
FETCH FIRST 1 ROWS ONLY;

SELECT * FROM SUPPLIER_REVIEWS;

SELECT 
  sr.review_id,
  sr.supplier_id,
  sr.review_text,
  sr.rating,
  sr.review_date,
  sr.submitted_by,
  -- Calculate hybrid score
  (0.7 * (1 - VECTOR_DISTANCE(sr.supply_review_vector, uq.vector, COSINE))) +
  (0.3 * (sr.rating / 5.0)) AS hybrid_score
FROM supplier_reviews sr
CROSS JOIN (
  SELECT question_vector AS vector
  FROM user_questions
  WHERE question_id = 7
) uq
ORDER BY hybrid_score DESC
FETCH FIRST 2 ROWS ONLY;
