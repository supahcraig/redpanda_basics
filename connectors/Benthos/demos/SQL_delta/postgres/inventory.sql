  
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


