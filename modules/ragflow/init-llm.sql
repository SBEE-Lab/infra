-- Initialize custom LLM models for user_default_llm
-- These entries enable get_init_tenant_llm() to populate tenant_llm for new users

INSERT IGNORE INTO llm (create_time, create_date, update_time, update_date, llm_name, model_type, fid, max_tokens, tags, is_tools, status)
VALUES
  -- Chat model: vLLM (Qwen3-32B-AWQ)
  (UNIX_TIMESTAMP()*1000, NOW(), UNIX_TIMESTAMP()*1000, NOW(), 'Qwen/Qwen3-32B-AWQ', 'chat', 'VLLM', 32768, 'LLM,CHAT,32k', 1, '1'),

  -- Embedding model: TEI (bge-m3)
  (UNIX_TIMESTAMP()*1000, NOW(), UNIX_TIMESTAMP()*1000, NOW(), 'BAAI/bge-m3', 'embedding', 'VLLM', 8192, 'TEXT EMBEDDING', 0, '1'),

  -- Rerank model: TEI (bge-reranker-v2-m3)
  (UNIX_TIMESTAMP()*1000, NOW(), UNIX_TIMESTAMP()*1000, NOW(), 'BAAI/bge-reranker-v2-m3', 'rerank', 'Huggingface', 8192, 'RERANK', 0, '1');
