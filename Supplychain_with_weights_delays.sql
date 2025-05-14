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

-- Add new column in supplier_reviews table -- 
ALTER TABLE supplier_reviews
ADD transit_delay_vector VECTOR;


-- Add those unstructured data into vectors --
BEGIN
  FOR r IN (SELECT review_id AS id, TRANSIT_DELAY_CATEGORY FROM supplier_reviews) LOOP
    UPDATE supplier_reviews
    SET transit_delay_vector =
        TO_VECTOR(
          VECTOR_EMBEDDING(
            MINILM_MODEL
            USING r.transit_delay_category AS DATA
          )
        )
    WHERE review_id = r.id;
  END LOOP;
  COMMIT;
END;

-- 1a) Define your “low delay” semantic vector once via a CROSS JOIN from DUAL
WITH low_delay_q AS (
  SELECT
    TO_VECTOR(
      VECTOR_EMBEDDING(
        MINILM_MODEL 
        USING 'low delay' AS DATA
      )
    ) AS q_vec
  FROM dual
),

-- 1b) Join items → reviews → the question vector, aggregate per supplier
supplier_stats AS (
  SELECT
    i.supplier_id,
    AVG(i.quantity_in_stock)     AS avg_stock,
    AVG(sr.rating)               AS avg_rating,
    AVG( VECTOR_DISTANCE(
           sr.transit_delay_vector,
           ld.q_vec,
           EUCLIDEAN
         )
    )                             AS avg_delay_dist
  FROM items i
  JOIN supplier_reviews sr
    ON sr.supplier_id = i.supplier_id
  CROSS JOIN low_delay_q ld
  GROUP BY i.supplier_id
)

-- 1c) Filter for “high stock” + “high rating” and sort by closeness-to-‘low delay’
SELECT
  supplier_id,
  avg_stock,
  avg_rating,
  avg_delay_dist
FROM supplier_stats
WHERE avg_stock   > 100      -- ← your high-stock threshold
  AND avg_rating  >= 4.0     -- ← your “high satisfaction” threshold
ORDER BY avg_delay_dist ASC  -- smaller distance → more semantically "low delay"
FETCH FIRST 10 ROWS ONLY;    -- top-10 suppliers


-- 2a -- 
WITH heavy_q AS (
  SELECT 
    TO_VECTOR(
      VECTOR_EMBEDDING(
        MINILM_MODEL 
        USING 'heavy items' AS DATA
      )
    ) AS q_vec
  FROM dual
)
SELECT
  i.supplier_id,
  COUNT(*)                                            AS item_count,
  AVG( VECTOR_DISTANCE(i.weight_category_vector,
                       h.q_vec,
                       EUCLIDEAN)
     )                                                 AS avg_heavy_dist
FROM items i
CROSS JOIN heavy_q h
GROUP BY i.supplier_id
ORDER BY avg_heavy_dist ASC   -- smaller → items more like “heavy”
FETCH FIRST 5 ROWS ONLY;       -- top-5 suppliers with heaviest items


--3a --
WITH light_q AS (
  SELECT 
    TO_VECTOR(
      VECTOR_EMBEDDING(
        MINILM_MODEL 
        USING 'light items' AS DATA
      )
    ) AS q_vec
  FROM dual
)
SELECT
  i.supplier_id,
  COUNT(*)                                            AS item_count,
  AVG( VECTOR_DISTANCE(i.weight_category_vector,
                       l.q_vec,
                       EUCLIDEAN)
     )                                                 AS avg_light_dist
FROM items i
CROSS JOIN light_q l
GROUP BY i.supplier_id
ORDER BY avg_light_dist ASC   -- smaller → items more like “light”
FETCH FIRST 5 ROWS ONLY;       -- top-5 suppliers with lightest items

select * from suppliers; 

select * from items; 

-- 4a --
WITH low_delay_q AS (
  SELECT
    TO_VECTOR(
      VECTOR_EMBEDDING(
        MINILM_MODEL
        USING 'low delay' AS DATA
      )
    ) AS q_vec
  FROM dual
),
supplier_stats AS (
  SELECT
    i.supplier_id,
    AVG(i.quantity_in_stock)                                           AS avg_stock,
    AVG(sr.rating)                                                     AS avg_rating,
    AVG( VECTOR_DISTANCE(sr.transit_delay_vector, ld.q_vec, EUCLIDEAN) ) AS avg_delay_dist
  FROM items i
  JOIN supplier_reviews sr
    ON sr.supplier_id = i.supplier_id
  CROSS JOIN low_delay_q ld
  GROUP BY i.supplier_id
)
SELECT
  s.supplier_name,
  s.contact_name,
  st.avg_stock,
  st.avg_rating,
  st.avg_delay_dist,
  LISTAGG(i.item_name, ', ') 
    WITHIN GROUP (ORDER BY i.item_name)   AS item_names
FROM supplier_stats st
JOIN suppliers s
  ON s.supplier_id = st.supplier_id
LEFT JOIN items i
  ON i.supplier_id = st.supplier_id
WHERE st.avg_stock  >  100    -- high-stock threshold
  AND st.avg_rating >= 4.0    -- high-satisfaction threshold
GROUP BY
  s.supplier_name,
  s.contact_name,
  st.avg_stock,
  st.avg_rating,
  st.avg_delay_dist
ORDER BY st.avg_delay_dist ASC
FETCH FIRST 10 ROWS ONLY;


-- 5a --

WITH
  -- 1) Concept vectors
  heavy_q AS (
    SELECT TO_VECTOR(
             VECTOR_EMBEDDING(MINILM_MODEL USING 'heavy items' AS DATA)
           ) AS heavy_vec
    FROM dual
  ),
  low_delay_q AS (
    SELECT TO_VECTOR(
             VECTOR_EMBEDDING(MINILM_MODEL USING 'low delay' AS DATA)
           ) AS delay_vec
    FROM dual
  ),

  -- 2) Compute per-supplier scores
  supplier_scores AS (
    SELECT
      i.supplier_id,
      AVG( VECTOR_DISTANCE(i.weight_category_vector, h.heavy_vec,   EUCLIDEAN) ) AS avg_heavy_dist,
      AVG( VECTOR_DISTANCE(sr.transit_delay_vector, d.delay_vec,    EUCLIDEAN) ) AS avg_delay_dist
    FROM items i
    JOIN supplier_reviews sr
      ON sr.supplier_id = i.supplier_id
    CROSS JOIN heavy_q    h
    CROSS JOIN low_delay_q d
    GROUP BY i.supplier_id
  )

-- 3) Join suppliers + items + aggregate item names
SELECT
  s.supplier_name,
  s.contact_name,
  ss.avg_heavy_dist,
  ss.avg_delay_dist,
  LISTAGG(i.item_name, ', ') 
    WITHIN GROUP (ORDER BY i.item_name) AS item_names
FROM supplier_scores ss
JOIN suppliers s
  ON s.supplier_id = ss.supplier_id
LEFT JOIN items i
  ON i.supplier_id = ss.supplier_id
GROUP BY
  s.supplier_name,
  s.contact_name,
  ss.avg_heavy_dist,
  ss.avg_delay_dist
ORDER BY
  ss.avg_heavy_dist ASC,    -- heaviest first
  ss.avg_delay_dist ASC     -- fastest (i.e. “low delay”) first
FETCH FIRST 10 ROWS ONLY;

--6a --
WITH
  -- 1) Build the “low delay” vector
  low_delay_q AS (
    SELECT
      TO_VECTOR(
        VECTOR_EMBEDDING(
          MINILM_MODEL        -- your loaded ONNX model
          USING 'low delay' AS DATA
        )
      ) AS delay_vec
    FROM dual
  ),

  -- 2) Per‐supplier, per‐category average delay
  category_delays AS (
    SELECT
      i.supplier_id,
      i.weight_category,
      AVG(
        VECTOR_DISTANCE(
          sr.transit_delay_vector,
          ld.delay_vec,
          EUCLIDEAN
        )
      ) AS avg_delay_dist
    FROM items i
    JOIN supplier_reviews sr
      ON sr.supplier_id = i.supplier_id
    CROSS JOIN low_delay_q ld
    GROUP BY i.supplier_id, i.weight_category
  ),

  -- 3) Compute consistency metrics per supplier
  supplier_consistency AS (
    SELECT
      supplier_id,
      MAX(avg_delay_dist) - MIN(avg_delay_dist) 
        AS delay_range,              -- smaller = more consistent
      STDDEV_POP(avg_delay_dist) 
        AS delay_stddev,             -- another consistency measure
      AVG(avg_delay_dist) 
        AS overall_avg_delay         -- lower = faster on average
    FROM category_delays
    GROUP BY supplier_id
  )

-- 4) Final select: supplier info + aggregated item names + metrics
SELECT
  sc.supplier_id,
  s.supplier_name,
  LISTAGG(i.item_name, ', ') 
    WITHIN GROUP (ORDER BY i.item_name) AS item_names,
  sc.delay_range,
  sc.delay_stddev,
  sc.overall_avg_delay
FROM supplier_consistency sc
JOIN suppliers s
  ON s.supplier_id = sc.supplier_id
LEFT JOIN items i
  ON i.supplier_id = sc.supplier_id
GROUP BY
  sc.supplier_id,
  s.supplier_name,
  sc.delay_range,
  sc.delay_stddev,
  sc.overall_avg_delay
ORDER BY
  sc.delay_range     ASC,   -- most consistent first
  sc.overall_avg_delay ASC -- then fastest on average
FETCH FIRST 10 ROWS ONLY;
