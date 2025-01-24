CREATE DATABASE inventory;

CREATE TABLE public.products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description VARCHAR(512),
    weight FLOAT
);


CREATE TABLE public.products_on_hand (
  product_id SERIAL PRIMARY KEY,
  quantity INT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES inventory.products(id)
);


CREATE TABLE public.customers (
  id SERIAL PRIMARY KEY,
  first_name VARCHAR(255) NOT NULL,
  last_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL UNIQUE
);


CREATE TABLE public.orders (
  id SERIAL PRIMARY KEY,
  order_date DATE NOT NULL,
  purchase_date DATE NOT NULL,
  purchaser INT NOT NULL,
  quantity INT NOT NULL,
  product_id INT NOT NULL,
  FOREIGN KEY (purchaser) REFERENCES inventory.customers(id),
  FOREIGN KEY (product_id) REFERENCES inventory.products(id)
);


