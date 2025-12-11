FROM postgres:15-alpine

# Set environment variables for demo
ENV POSTGRES_DB=demo_db
ENV POSTGRES_USER=demo_user  
ENV POSTGRES_PASSWORD=demo_password

# Create initialization script
RUN mkdir -p /docker-entrypoint-initdb.d

# Create demo data
RUN echo "CREATE TABLE IF NOT EXISTS demo_table (\n\
  id SERIAL PRIMARY KEY,\n\
  name VARCHAR(100),\n\
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP\n\
);\n\
\n\
INSERT INTO demo_table (name) VALUES \n\
  ('Sample Data 1'),\n\
  ('Sample Data 2'),\n\
  ('Container Demo'),\n\
  ('PostgreSQL Working');\n\
\n\
-- Create a simple status view\n\
CREATE OR REPLACE VIEW system_status AS\n\
SELECT \n\
  'PostgreSQL Database' as service,\n\
  version() as version,\n\
  current_database() as database,\n\
  current_user as user,\n\
  now() as timestamp;\n\
" > /docker-entrypoint-initdb.d/init.sql

EXPOSE 5432

# Keep the default postgres entrypoint
CMD ["postgres"]