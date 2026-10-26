DELETE FROM platform."AgentGraphExecution" WHERE "agentGraphId"='756528c7-cead-4971-835a-eae00a67e26c';
DELETE FROM platform."LibraryAgent" WHERE "agentGraphId"='756528c7-cead-4971-835a-eae00a67e26c';
DELETE FROM platform."AgentGraph" WHERE id='756528c7-cead-4971-835a-eae00a67e26c';
SELECT id, name FROM platform."AgentGraph";
