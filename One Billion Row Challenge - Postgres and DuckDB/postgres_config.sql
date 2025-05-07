ALTER SYSTEM SET max_worker_processes=32;
ALTER SYSTEM SET max_parallel_workers=16;
ALTER SYSTEM SET max_parallel_workers_per_gather=16;
ALTER SYSTEM SET work_mem='1GB';
ALTER SYSTEM SET shared_buffers='20GB';
ALTER SYSTEM SET random_page_cost=1.1;
ALTER SYSTEM SET jit=OFF;

