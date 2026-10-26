DELETE FROM platform."AgentGraphExecution" WHERE "agentGraphId"='ef1c7891-5a6c-4711-b250-856a62483638';
DELETE FROM platform."LibraryAgent" WHERE "agentGraphId"='ef1c7891-5a6c-4711-b250-856a62483638';
DELETE FROM platform."AgentGraph" WHERE id='ef1c7891-5a6c-4711-b250-856a62483638';
SELECT 'CLEANUP_OK';
