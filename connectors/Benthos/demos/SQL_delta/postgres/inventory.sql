  
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(512),
    weight FLOAT
);


CREATE TABLE products_on_hand (
  product_id SERIAL PRIMARY KEY,
  quantity INT NOT NULL
);


CREATE TABLE customers (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);


CREATE TABLE orders (
  id SERIAL PRIMARY KEY,
  order_date DATE NOT NULL,
  purchase_date DATE NOT NULL,
  purchaser INT NOT NULL,
  quantity INT NOT NULL,
  product_id INT NOT NULL
);


CREATE TABLE content_notification (
  id uuid primary key,
  destination_system VARCHAR(25),
  notification_type VARCHAR(25),
  status VARCHAR(25),
  duration FLOAT,
  notification_date DATE,
  d_notification_date DATE DEFAULT CURRENT_DATE,
  notification_timestamp TIMESTAMP,
  d_notification_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  notification_timestamp_tz TIMESTAMPTZ,
  d_notification_timestamp_tz TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
