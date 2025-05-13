select * from items;

-- ADD new column for weight_category with unstructured data: low, medium or heavy based on the weights of the items -- 
ALTER TABLE items
ADD weight_category_vector VECTOR;

-- Importing the embedding model to vectorize the unstructured data --
BEGIN
DBMS_CLOUD.CREATE_CREDENTIAL(
  credential_name => 'FREE23AI_CRED',
  username => 'My_OCI_Username',
  password => 'My_OCI_Username_AuthToken'
);
END;

DECLARE
    ONNX_MOD_FILE VARCHAR2(100) := 'all_MiniLM_L12_v2.onnx';
    MODNAME VARCHAR2(500) = '$BUCKET_SECRET';
BEGIN
    MODNAME := 'MINILM_MODEL'; 

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


-- Vectorize the weight_category column into weight_category_vector -- 
BEGIN
  FOR r IN (SELECT ITEM_ID AS id, weight_category FROM items) LOOP
    UPDATE items
    SET weight_category_vector =
        TO_VECTOR(
          VECTOR_EMBEDDING(
            MINILM_MODEL
            USING r.weight_category AS DATA
          )
        )
    WHERE item_id = r.id;
  END LOOP;
  COMMIT;
END;


